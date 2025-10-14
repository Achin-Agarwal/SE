import dotenv from 'dotenv';
dotenv.config();

const config = {
    server: {
        port: process.env.PORT,
    },
    database: {
        uri: process.env.MONGO_URI,
    },
    auth: {
        tokenSecret: process.env.ACCESS_TOKEN_SECRET,
        tokenExpiration: '7d',
    },
};

export default config;