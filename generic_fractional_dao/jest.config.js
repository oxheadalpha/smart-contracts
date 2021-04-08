module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  transform: {
    "node_modules/smart-contracts-common/.+\\.(j|t)sx?$": "ts-jest",
  },
  transformIgnorePatterns: ["node_modules/(?!smart-contracts-common/.*)"],
  // testMatch: ['**/__tests__/*.+(spec|test).[jt]s?(x)']
};
