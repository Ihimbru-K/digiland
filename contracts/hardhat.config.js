require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.19",
  networks: {
    amoy: {
      url: "https://rpc-amoy.polygon.technology",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 80002,
      gasPrice: 30000000000,
    },
  },
  etherscan: {
    apiKey: {
      polygonAmoy: process.env.POLYGONSCAN_API_KEY || "",
    },
    customChains: [
      {
        network: "polygonAmoy",
        chainId: 80002,
        urls: {
          apiURL: "https://api-amoy.polygonscan.com/api",
          browserURL: "https://amoy.polygonscan.com",
        },
      },
    ],
  },
};




// require("@nomicfoundation/hardhat-toolbox");
// require("dotenv").config();

// /** @type import('hardhat/config').HardhatUserConfig */
// module.exports = {
//   solidity: "0.8.19",
//   networks: {
//     amoy: {
//       url: "https://rpc-amoy.polygon.technology",
//       accounts: [process.env.PRIVATE_KEY],
//       chainId: 80002,
//     },
//   },
//   etherscan: {
//     apiKey: {
//       polygonAmoy: process.env.POLYGONSCAN_API_KEY || "",
//     },
//     customChains: [
//       {
//         network: "polygonAmoy",
//         chainId: 80002,
//         urls: {
//           apiURL: "https://api-amoy.polygonscan.com/api",
//           browserURL: "https://amoy.polygonscan.com",
//         },
//       },
//     ],
//   },
// };
