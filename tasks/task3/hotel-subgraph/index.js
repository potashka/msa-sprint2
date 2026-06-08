import { ApolloServer } from '@apollo/server';
import { startStandaloneServer } from '@apollo/server/standalone';
import { buildSubgraphSchema } from '@apollo/subgraph';
import gql from 'graphql-tag';

const MONOLITH_URL = process.env.MONOLITH_URL;

const mockHotels = [
  { id: 'hotel-1', name: 'Hotelio Seoul Central', city: 'Seoul', rating: 4.8, stars: 5 },
  { id: 'hotel-2', name: 'Hotelio Busan Harbor', city: 'Busan', rating: 4.4, stars: 4 },
  { id: 'hotel-3', name: 'Hotelio Daegu Garden', city: 'Daegu', rating: 4.1, stars: 4 }
];

function normalizeHotel(raw, id) {
  if (!raw) return null;
  const rating = raw.rating == null ? null : Number(raw.rating);
  return {
    id: raw.id || id,
    name: raw.name || raw.description || `Hotel ${raw.id || id}`,
    city: raw.city || null,
    rating,
    stars: raw.stars || (rating == null ? null : Math.round(rating))
  };
}

async function fetchHotelFromMonolith(id) {
  if (!MONOLITH_URL) return null;

  try {
    const response = await fetch(`${MONOLITH_URL}/api/hotels/${encodeURIComponent(id)}`);
    if (!response.ok) {
      console.log(`[hotel-subgraph] MONOLITH_URL lookup failed id=${id} status=${response.status}, using mock fallback`);
      return null;
    }
    return normalizeHotel(await response.json(), id);
  } catch (error) {
    console.log(`[hotel-subgraph] MONOLITH_URL unavailable id=${id}: ${error.message}, using mock fallback`);
    return null;
  }
}

async function fetchHotel(id) {
  return (await fetchHotelFromMonolith(id)) || mockHotels.find((hotel) => hotel.id === id) || null;
}

async function fetchHotels(ids) {
  return Promise.all(ids.map((id) => fetchHotel(id)));
}

const typeDefs = gql`
  type Hotel @key(fields: "id") {
    id: ID!
    name: String
    city: String
    rating: Float
    stars: Int
  }

  type Query {
    hotelsByIds(ids: [ID!]!): [Hotel]
  }
`;

const resolvers = {
  Hotel: {
    __resolveReference: async ({ id }) => {
      const hotel = await fetchHotel(id);
      console.log(`[hotel-subgraph] __resolveReference id=${id} found=${Boolean(hotel)}`);
      return hotel;
    }
  },
  Query: {
    hotelsByIds: async (_, { ids }) => {
      console.log(`[hotel-subgraph] hotelsByIds ids=${ids.join(',')}`);
      return fetchHotels(ids);
    }
  }
};

const server = new ApolloServer({
  schema: buildSubgraphSchema([{ typeDefs, resolvers }])
});

startStandaloneServer(server, {
  listen: { host: '0.0.0.0', port: 4002 }
}).then(({ url }) => {
  console.log(`Hotel subgraph ready at ${url}`);
});
