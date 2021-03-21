module.exports = flatten;

/**
 * @template T
 * @param {T[][]} array
 * @returns {T[]}
 */
function flatten(array) {
  return /** @type {T[]} */ ([]).concat(...array);
}
