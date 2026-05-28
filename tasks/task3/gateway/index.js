import { ApolloServer } from '@apollo/server';
import { startStandaloneServer } from '@apollo/server/standalone';
import { ApolloGateway, RemoteGraphQLDataSource } from '@apollo/gateway';

const gateway = new ApolloGateway({
  serviceList: [
    { name: 'booking', url: process.env.BOOKING_SUBGRAPH_URL || 'http://booking-subgraph:4001' },
    { name: 'hotel', url: process.env.HOTEL_SUBGRAPH_URL || 'http://hotel-subgraph:4002' }
  ],
  buildService({ url }) {
    return new RemoteGraphQLDataSource({
      url,
      willSendRequest({ request, context }) {
        const userId = context.req?.headers?.userid;
        if (userId) {
          request.http.headers.set('userid', userId);
        }
      }
    });
  }
});

const server = new ApolloServer({ gateway });

startStandaloneServer(server, {
  listen: { host: '0.0.0.0', port: 4000 },
  context: async ({ req }) => ({ req })
}).then(({ url }) => {
  console.log(`Apollo Gateway ready at ${url}`);
});
