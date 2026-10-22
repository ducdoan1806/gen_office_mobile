import { zlibSync } from 'fflate';
export const deflateSync = (bytes: Uint8Array) => zlibSync(bytes);
