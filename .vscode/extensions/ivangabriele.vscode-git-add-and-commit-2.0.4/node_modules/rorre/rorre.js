let _DICTIONARY
let _ERROR
let _NAME

/**
 * RorreError customizes the default Error:
 * - make #name property compulsory (nonexistent in Node and only optional in a browser),
 * - add an #index property in order to generate error indexes within Rorre dictionary.
 */
class RorreError extends Error {
  constructor(message, name) {
    switch (true) {
      case typeof message !== 'string' || message.length === 0:
        throw new Error(`RorreError(): The <message> must be a non-empty string.`)

      case typeof name !== 'string' || name.length === 0:
        throw new Error(`RorreError(): The <name> must be a non-empty string.`)
    }

    super(message)

    this.name = name
  }
}

class Rorre {
  /**
   * Get the complete error dictionary indexed object.
   *
   * @description
   * This is an enumed mapping: for each error, both its #message
   * and generated #index exist as a key, and a value as well.
   */
  get dictionary() {
    if (_DICTIONARY === undefined) {
      throw new Error(`Rorre#dictionary: You need to declare your dictionary first, in order to call this getter.`)
    }

    return _DICTIONARY
  }

  /**
   * Instanciate (but do NOT throw) a RorreError and return it.
   */
  get error() {
    if (_DICTIONARY === undefined) {
      throw new Error(`Rorre#code: You need to declare your dictionary first, in order to call this getter.`)
    }

    return _ERROR
  }


  /**
   * Get an enum of the dictionary errors' name.
   *
   * @description
   * This is a reverse mapping: for each error, both its #name
   * and generated #index exist as a key, and a value as well.
   */
  get name() {
    if (_DICTIONARY === undefined) {
      throw new Error(`Rorre#code: You need to declare your dictionary first, in order to call this getter.`)
    }

    return _NAME
  }

  /**
   * Declare the complete errors dictionary.
   *
   * @description
   * This method can and must only be called once.
   */
  declare(dictionary) {
    switch (true) {
      case _DICTIONARY !== undefined:
        throw new Error(`Rorre#declare(): You already declared an error dictionary.`)

      case Object.prototype.toString.call(dictionary) !== '[object Object]':
        throw new Error(`Rorre#declare(): Your <dictionary> must be a pure object: { ... }.`)

      case Object.entries(dictionary).length === 0:
        throw new Error(`Rorre#declare(): Your <dictionary> can't be empty.`)

      case Object.entries(dictionary).filter(([_, m]) => typeof m !== 'string' || m.length === 0).length !== 0:
        throw new Error(`Rorre#declare(): Your <dictionary> values (= messages) must be non-empty strings.`)
    }

    // Iitialize the "private properties"
    _DICTIONARY = {}
    _ERROR = {}
    _NAME = {}

    // Fill the "private properties"
    for (let name in dictionary) {
      _NAME[name] = name
      _DICTIONARY[name] = dictionary[name]
      _ERROR[name] = () => new RorreError(dictionary[name], name)
    }

    // Freeze the "private properties"
    _DICTIONARY = Object.freeze(_DICTIONARY)
    _ERROR = Object.freeze(_ERROR)
    _NAME = Object.freeze(_NAME)

    return this
  }
}

module.exports = Object.seal(new Rorre())

// Enable Typescript default importation
module.exports.default = module.exports
