module.exports = keyBy;

/**
 * @template T
 * @template {string} K
 * @param {T[]} array
 * @param {(element: T) => K} keyFunc
 * @returns {Record<K, T>}
 */
function keyBy(array, keyFunc) {
  return array.reduce((hash, element) => {
    hash[keyFunc(element)] = element;
    return hash;
  }, /** @type {Record<K, T>} */ ({}));
}
