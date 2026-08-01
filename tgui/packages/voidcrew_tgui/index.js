/**
 * code from raffclar
 * taken from https://github.com/fulpstation/fulpstation/pull/612
 */

// voidcrew edit - exclude *.test.tsx from the game bundle (matches upstream routes.tsx)
const INTERFACE_FILES = /^(?!.*\.test\.(tsx?|jsx?)).*\.(tsx?|jsx?)$/;
const requireModularInterface = require.context('./interfaces', true, INTERFACE_FILES);
const requireTgInterface = require.context('../tgui/interfaces', true, INTERFACE_FILES);

const getComponent = (interfacePath, requireInterface) => {
  let esModule = null;

  try {
    esModule = requireInterface(interfacePath);
  } catch (err) {
    if (err.code !== 'MODULE_NOT_FOUND') {
      throw err;
    }
  }

  return esModule;
};

/**
 * This places precedence on Voidcrew's interfaces over the default ones
 */
export const loadInterface = (interfacePath) => {
  let esModule = getComponent(interfacePath, requireModularInterface);

  if (esModule) {
    return esModule;
  }

  return getComponent(interfacePath, requireTgInterface);
};
