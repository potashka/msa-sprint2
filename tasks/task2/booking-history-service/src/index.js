const { Kafka } = require('kafkajs');
const { Pool } = require('pg');

const KAFKA_BROKERS = (process.env.KAFKA_BROKERS || 'kafka:9092').split(',');
const BOOKING_TOPIC = process.env.BOOKING_TOPIC || 'booking.created';

const pool = new Pool({
  host: process.env.PGHOST || 'history-db',
  port: Number(process.env.PGPORT || 5432),
  database: process.env.PGDATABASE || 'history',
  user: process.env.PGUSER || 'history',
  password: process.env.PGPASSWORD || 'history'
});

const kafka = new Kafka({ clientId: 'booking-history-service', brokers: KAFKA_BROKERS });
const consumer = kafka.consumer({ groupId: 'booking-history-service' });

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
  await retry('history-db', () => pool.query('select 1'));
  await pool.query(`
    CREATE TABLE IF NOT EXISTS booking_history (
      id SERIAL PRIMARY KEY,
      booking_id TEXT,
      user_id TEXT,
      hotel_id TEXT,
      promo_code TEXT,
      discount_percent DOUBLE PRECISION,
      price DOUBLE PRECISION,
      created_at TIMESTAMPTZ,
      consumed_at TIMESTAMPTZ DEFAULT now()
    )
  `);
}

async function main() {
  await initDb();
  await retry('kafka', () => consumer.connect());
  await consumer.subscribe({ topic: BOOKING_TOPIC, fromBeginning: true });

  await consumer.run({
    eachMessage: async ({ message }) => {
      const event = JSON.parse(message.value.toString());
      await pool.query(
        `INSERT INTO booking_history
          (booking_id, user_id, hotel_id, promo_code, discount_percent, price, created_at)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [
          event.id,
          event.user_id,
          event.hotel_id,
          event.promo_code || null,
          Number(event.discount_percent || 0),
          Number(event.price || 0),
          event.created_at
        ]
      );
      console.log(`Stored BookingCreated event for booking ${event.id}`);
    }
  });
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
