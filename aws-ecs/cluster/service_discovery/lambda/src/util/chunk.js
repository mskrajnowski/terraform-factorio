module.exports = chunk;

/**
 * @template T
 * @param {T[]} array
 * @param {number} size
 * @returns {T[][]}
 */
function chunk(array, size) {
  /** @type T[][] */
  const chunks = [];

  for (let start = 0; start < array.length; start += size) {
    chunks.push(array.slice(start, start + size));
  }

  return chunks;
}
