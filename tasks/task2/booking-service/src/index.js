const path = require('path');
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');
const axios = require('axios');
const { Kafka } = require('kafkajs');
const { Pool } = require('pg');

const GRPC_HOST = process.env.GRPC_HOST || '0.0.0.0';
const GRPC_PORT = Number(process.env.GRPC_PORT || 9090);
const MONOLITH_URL = process.env.MONOLITH_URL || 'http://monolith:8080';
const KAFKA_BROKERS = (process.env.KAFKA_BROKERS || 'kafka:9092').split(',');
const BOOKING_TOPIC = process.env.BOOKING_TOPIC || 'booking.created';

const pool = new Pool({
  host: process.env.PGHOST || 'booking-db',
  port: Number(process.env.PGPORT || 5432),
  database: process.env.PGDATABASE || 'booking',
  user: process.env.PGUSER || 'booking',
  password: process.env.PGPASSWORD || 'booking'
});

const kafka = new Kafka({ clientId: 'booking-service', brokers: KAFKA_BROKERS });
const producer = kafka.producer();

const packageDefinition = protoLoader.loadSync(path.join(__dirname, '..', 'booking.proto'), {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true
});
const bookingProto = grpc.loadPackageDefinition(packageDefinition).booking;

function boolValue(value) {
  if (typeof value === 'boolean') return value;
  return String(value).replace(/"/g, '').trim().toLowerCase() === 'true';
}

function normalizeText(value) {
  return String(value || '').replace(/"/g, '').trim();
}

async function retry(name, fn, attempts = 30) {
  let lastError;
  for (let i = 1; i <= attempts; i += 1) {
    try {
      return await fn();
    } catch (err) {
      lastError = err;
      console.log(`${name} is not ready yet (${i}/${attempts}): ${err.message}`);
      await new Promise((resolve) => setTimeout(resolve, 2000));
    }
  }
  throw lastError;
}

async function initDb() {
  await retry('booking-db', () => pool.query('select 1'));
  await pool.query(`
    CREATE TABLE IF NOT EXISTS bookings (
      id SERIAL PRIMARY KEY,
      user_id TEXT NOT NULL,
      hotel_id TEXT NOT NULL,
      promo_code TEXT,
      discount_percent DOUBLE PRECISION,
      price DOUBLE PRECISION NOT NULL,
      created_at TIMESTAMPTZ DEFAULT now()
    )
  `);
}

async function validateUser(userId) {
  const [active, blacklisted, status] = await Promise.all([
    axios.get(`${MONOLITH_URL}/api/users/${encodeURIComponent(userId)}/active`),
    axios.get(`${MONOLITH_URL}/api/users/${encodeURIComponent(userId)}/blacklisted`),
    axios.get(`${MONOLITH_URL}/api/users/${encodeURIComponent(userId)}/status`)
  ]);

  if (!boolValue(active.data)) throw new Error('User is inactive');
  if (boolValue(blacklisted.data)) throw new Error('User is blacklisted');
  return normalizeText(status.data);
}

async function validateHotel(hotelId) {
  const [operational, fullyBooked, trusted] = await Promise.all([
    axios.get(`${MONOLITH_URL}/api/hotels/${encodeURIComponent(hotelId)}/operational`),
    axios.get(`${MONOLITH_URL}/api/hotels/${encodeURIComponent(hotelId)}/fully-booked`),
    axios.get(`${MONOLITH_URL}/api/reviews/hotel/${encodeURIComponent(hotelId)}/trusted`)
  ]);

  if (!boolValue(operational.data)) throw new Error('Hotel is not operational');
  if (boolValue(fullyBooked.data)) throw new Error('Hotel is fully booked');
  if (!boolValue(trusted.data)) throw new Error('Hotel is not trusted based on reviews');
}

async function resolvePromoDiscount(promoCode, userId) {
  if (!promoCode) return 0.0;
  try {
    const response = await axios.post(`${MONOLITH_URL}/api/promos/validate`, null, {
      params: { code: promoCode, userId }
    });
    return Number(response.data.discount ?? response.data.discountPercent ?? 0);
  } catch (err) {
    console.log(`Promo ${promoCode} is invalid for user ${userId}: ${err.message}`);
    return 0.0;
  }
}

function toBookingResponse(row) {
  return {
    id: String(row.id),
    user_id: row.user_id,
    hotel_id: row.hotel_id,
    promo_code: row.promo_code || '',
    discount_percent: Number(row.discount_percent || 0),
    price: Number(row.price),
    created_at: new Date(row.created_at).toISOString()
  };
}

async function createBooking(call, callback) {
  const userId = call.request.user_id;
  const hotelId = call.request.hotel_id;
  const promoCode = call.request.promo_code || null;

  try {
    const status = await validateUser(userId);
    await validateHotel(hotelId);

    const basePrice = status.toUpperCase() === 'VIP' ? 80.0 : 100.0;
    const discount = await resolvePromoDiscount(promoCode, userId);
    const price = basePrice - discount;

    const result = await pool.query(
      `INSERT INTO bookings (user_id, hotel_id, promo_code, discount_percent, price)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, user_id, hotel_id, promo_code, discount_percent, price, created_at`,
      [userId, hotelId, promoCode, discount, price]
    );
    const response = toBookingResponse(result.rows[0]);

    await producer.send({
      topic: BOOKING_TOPIC,
      messages: [{ key: response.id, value: JSON.stringify({ type: 'BookingCreated', ...response }) }]
    });

    callback(null, response);
  } catch (err) {
    console.error('CreateBooking failed:', err.message);
    callback({
      code: grpc.status.INVALID_ARGUMENT,
      message: err.message
    });
  }
}

async function listBookings(call, callback) {
  try {
    const userId = call.request.user_id;
    const result = userId
      ? await pool.query('SELECT * FROM bookings WHERE user_id = $1 ORDER BY id', [userId])
      : await pool.query('SELECT * FROM bookings ORDER BY id');
    callback(null, { bookings: result.rows.map(toBookingResponse) });
  } catch (err) {
    callback({ code: grpc.status.INTERNAL, message: err.message });
  }
}

async function main() {
  await initDb();
  await retry('kafka', () => producer.connect());

  const server = new grpc.Server();
  server.addService(bookingProto.BookingService.service, {
    CreateBooking: createBooking,
    ListBookings: listBookings
  });
  server.bindAsync(`${GRPC_HOST}:${GRPC_PORT}`, grpc.ServerCredentials.createInsecure(), (err, port) => {
    if (err) throw err;
    console.log(`booking-service gRPC listening on ${GRPC_HOST}:${port}`);
    server.start();
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
