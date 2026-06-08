const path = require('path');
const grpc = require('@grpc/grpc-js');
const protoLoader = require('@grpc/proto-loader');

const target = process.env.BOOKING_GRPC_TARGET || 'localhost:9090';
const userId = process.argv[2] || '';

const packageDefinition = protoLoader.loadSync(path.join(__dirname, '..', 'booking.proto'), {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true
});
const bookingProto = grpc.loadPackageDefinition(packageDefinition).booking;
const client = new bookingProto.BookingService(target, grpc.credentials.createInsecure());

client.ListBookings({ user_id: userId }, (err, response) => {
  if (err) {
    console.error(err.message);
    process.exit(1);
  }
  console.log(JSON.stringify(response.bookings, null, 2));
});
