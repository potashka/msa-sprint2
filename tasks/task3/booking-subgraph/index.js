import { ApolloServer } from '@apollo/server';
import { startStandaloneServer } from '@apollo/server/standalone';
import { buildSubgraphSchema } from '@apollo/subgraph';
import gql from 'graphql-tag';

const mockBookings = [
  {
    id: 'b1',
    userId: 'user1',
    hotelId: 'hotel-1',
    promoCode: 'SUMMER2024',
    discountPercent: 10
  },
  {
    id: 'b2',
    userId: 'user1',
    hotelId: 'hotel-2',
    promoCode: null,
    discountPercent: 0
  },
  {
    id: 'b3',
    userId: 'user2',
    hotelId: 'hotel-3',
    promoCode: 'VIP20',
    discountPercent: 20
  }
];

async function fetchBookings(userId) {
  return mockBookings.filter((booking) => booking.userId === userId);
}

const typeDefs = gql`
  type Booking @key(fields: "id") {
    id: ID!
    userId: String!
    hotelId: String!
    promoCode: String
    discountPercent: Int
    hotel: Hotel
  }

  type Hotel @key(fields: "id") {
    id: ID!
  }

  type Query {
    bookingsByUser(userId: String!): [Booking!]!
  }
`;

const resolvers = {
  Query: {
    bookingsByUser: async (_, { userId }, { req }) => {
      const headerUserId = req?.headers?.userid;
      const allowed = Boolean(headerUserId) && headerUserId === userId;

      console.log(
        `[booking-subgraph] bookingsByUser requestedUser=${userId} headerUser=${headerUserId || 'missing'} acl=${allowed ? 'ALLOW' : 'DENY'}`
      );

      if (!allowed) {
        return [];
      }

      const bookings = await fetchBookings(userId);
      console.log(`[booking-subgraph] bookingsByUser resultCount=${bookings.length}`);
      return bookings;
    }
  },
  Booking: {
    hotel: (booking) => ({ __typename: 'Hotel', id: booking.hotelId })
  }
};

const server = new ApolloServer({
  schema: buildSubgraphSchema([{ typeDefs, resolvers }])
});

startStandaloneServer(server, {
  listen: { host: '0.0.0.0', port: 4001 },
  context: async ({ req }) => ({ req })
}).then(({ url }) => {
  console.log(`Booking subgraph ready at ${url}`);
});
