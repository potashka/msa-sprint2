FROM node:20-alpine

WORKDIR /app

COPY booking-service/package.json ./
RUN npm install --omit=dev

COPY booking.proto ./booking.proto
COPY booking-service/src ./src

CMD ["npm", "start"]
