FROM node:22-slim

WORKDIR /app

# Install openssl for Prisma compatibility
RUN apt-get update -y && apt-get install -y openssl

COPY package*.json ./
COPY prisma ./prisma/

RUN npm install

COPY . .

RUN npm run prisma:generate

EXPOSE 8000

CMD ["npm", "start"]
