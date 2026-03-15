import jwt , {  JwtPayload, SignOptions } from 'jsonwebtoken';
import type { StringValue} from "ms";
import {config} from '../config';

export interface TokenPayload {
    userId: string;
    email: string;
    rol: string;


}

export function generateToken(payload: TokenPayload): string {
    return jwt.sign(payload, config.jwtSecret, { expiresIn: config.jwtExpiresIn } as SignOptions);
};
  
//Tokeni dogrular ve içindeki bilgileri döndürür
export function verifyToken(token: string): TokenPayload {
    return jwt.verify(token, config.jwtSecret) as TokenPayload;
}


