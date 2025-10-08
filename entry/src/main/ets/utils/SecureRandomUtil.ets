import { cryptoFramework } from '@kit.CryptoArchitectureKit';

/**
 * Generates a secure random number between 0 (inclusive) and 1 (exclusive)
 * using synchronous crypto operations.
 * @returns A random number between 0 and 1
 */
export function secureRandomNumber(): number {
  const rand = cryptoFramework.createRandom();
  const len = 8; // 8 bytes (64 bits)
  const randData = rand.generateRandomSync(len);
  const bytes = randData.data;
  let bigIntValue = BigInt(0);
  // Combine all 64 bits into a BigInt
  for (let i = 0; i < 8; i++) {
    bigIntValue = (bigIntValue << BigInt(8)) | BigInt(bytes[i]);
  }
  // Take the upper 53 bits for full floating-point precision
  const maxSafeValue = BigInt(1) << BigInt(53); // 2^53
  const normalizedValue = Number(bigIntValue >> BigInt(11)) / Number(maxSafeValue);
  return normalizedValue;
}