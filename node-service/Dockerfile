FROM node:20-alpine AS development
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY prisma ./prisma
RUN npx prisma generate
# tüm kaynak kodu kopyalar
COPY . .
# prisma generate, schema dosyasi kopyalandiktan sonra calistirilmali

# 3000 portunu disari acar
EXPOSE 3000
CMD ["npm", "run", "dev"]
