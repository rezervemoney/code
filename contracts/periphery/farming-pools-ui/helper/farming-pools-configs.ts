// PoolType enum mapping
enum PoolType {
  PENDLE = 0,
  SPECTRA = 1,
  BEETS = 2,
  SHADOW = 3,
  EQUALIZER = 4,
  EULER = 5,
  REZERVE = 6,
  BALANCER = 7,
  CURVE = 8,
  UNISWAP = 9
}

// PoolConfig structure matching the Solidity contract
interface PoolConfig {
  poolAddress: string;
  poolType: PoolType;
  gauge: string; 
  oracle: string;
  // tokens: string[];
}

// Network configuration structure
interface NetworkConfig {
  rzrOracle: string;
  pools: PoolConfig[];
}

// Sonic chain data (chainId: 146)
const SonicFarmingPoolData: PoolConfig[] = [
  {
    poolAddress: "0x67a298e5b65db2b4616e05c3b455e017275f53cb",
    poolType: PoolType.REZERVE,
    gauge: "0x0000000000000000000000000000000000000000",
    oracle: "0xF576C9ccCb0244B4F0B11A99eCb357CE692d1ebC",
    // tokens: ["0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5"] // RZR address placeholder
  },
  {
    poolAddress: "0x08c5e3b7533ee819a4d1f66e839d0e8f04ae3d0c",
    poolType: PoolType.SHADOW,
    gauge: "0xf5D3CBde40c46e0c0a4904c63f26BeB6229cC95F",
    oracle: "0x5e7c3Efb5Ba307ec9F7e2A75B0470101c5e9ecd9",
    // tokens: ["0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5", "0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE"] // RZR, scUSD address placeholders
  },
  {
    poolAddress: "0xdd30ded4a23bc03268dcac62538f45b55633d94a",
    poolType: PoolType.BEETS,
    gauge: "0xa0c7104dc826e52ca9cadf4970858ab2f844b7df",
    oracle: "0x8681a10007097f9b600A4B428231Dd1e50a2ba49",
    // tokens: ["0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5", "0x67A298e5B65dB2b4616E05C3b455E017275f53cB"] // RZR, lstRZR address placeholders
  },
  {
    poolAddress: "0x36e6765907DD61b50Ad33F79574dD1B63339B59c",
    poolType: PoolType.BEETS,
    gauge: "0x044aa51369d8ecd3d0a3e7e0437389499d674802",
    oracle: "0x846261507241b47DE8655c3E50f68b0c483A2D45",
    // tokens: ["0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5", "0xE5DA20F15420aD15DE0fa650600aFc998bbE3955"] // RZR, stS address placeholders
  },
  {
    poolAddress: "0xf0b29acebb577c52a7afbecdcdd9dbfd3b82cf12",
    poolType: PoolType.BEETS,
    gauge: "0x17b90abbf5367b9bbee94cbb7e606f61dd2a2c10", 
    oracle: "0xBfC2f82e4422Cd6435a61743C911f3bC39251C64", 
    // tokens: ["0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5", "0x50c42dEAcD8Fc9773493ED674b675bE577f2634b"] // RZR, WETH address placeholders
  },
  {
    poolAddress: "0x307cc0ab64dc0496cc113357ee14c53d4db4b966",
    poolType: PoolType.BEETS,
    gauge: "0xb83f533dfe1af40a9ff38fc133c24293e046ad69",
    oracle: "0x578Cf67F43efa560b7b151300008cbE3dc7F6d61",
    // tokens: ["0x67A298e5B65dB2b4616E05C3b455E017275f53cB", "0xE5DA20F15420aD15DE0fa650600aFc998bbE3955"] // lstRZR, stS address placeholders
  },
  {
    poolAddress: "0xabfc41b413891c647d0d1cd66bf64bc6ed8fee71",
    poolType: PoolType.PENDLE,
    gauge: "0x0000000000000000000000000000000000000000",
    oracle: "0xbaB9e6c125569427C6688DF56ab6d42A4b8e6bE8",
    //
  },
  {
    poolAddress: "0x17cd5228da53f244a96fc6e5415bdcdc06348a46",
    poolType: PoolType.SPECTRA,
    gauge: "0x0000000000000000000000000000000000000000",
    oracle: "0x4DbAF550e8865a88bbd4Cee7800d5142F23Ea4Ec",
    // tokens: ["0xb4444468e444f89e1c2cac2f1d3ee7e336cbd1f5","0x67a298e5b65db2b4616e05c3b455e017275f53cb","0xb90c4f1684602ac28d9fbbfe9a6c1db325c37e24", "0x901c2E1b6BB68DB37A7c4F9b7AA4BeD90201cE00" ] // RZR(underlying), lstRZR(IBT), PT, YT address placeholder
  },
  {
    poolAddress: "0xFF3a2650C5ffd0745FB93261671E6d3E95f2C082",
    poolType: PoolType.EQUALIZER,
    gauge: "0xb702c26e892239a7ef71B13695440227080d1DFF",    
    oracle: "0x5e7c3Efb5Ba307ec9F7e2A75B0470101c5e9ecd9",
    // tokens: ["0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5", "0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE"] // RZR, scUSD address placeholders
  },
  {
    poolAddress: "0xD9925FB0f88D087FfEdFCD88b032e55c82d171Df",
    poolType: PoolType.EQUALIZER,
    gauge: "0xeAd7868F221044D9828C8d2e19579D806BD7A98A",
    oracle: "0x4CBe17B6304460A76BC227831aD62d89fBfB499E", 
    // tokens: ["0xb4444468e444f89e1c2CAc2F1D3ee7e336cBD1f5", "0x67A298e5B65dB2b4616E05C3b455E017275f53cB"] // RZR, lstRZR address placeholders
  },
  {
    poolAddress: "0x9CcF74E64922D8a48b87AA4200b7c27B2B1D860a",
    poolType: PoolType.EULER,
    gauge: "0x0000000000000000000000000000000000000000",
    oracle: "0x0b5695dF5620Ca00ABAE19aEC6AEdd0f71C616D9", 
    // tokens: ["0x29219dd400f2Bf60E5a23d13Be72B486D4038894"] // USDC address placeholder
  }
];

// Mainnet chain data (chainId: 1)
const MainnetFarmingPoolData: PoolConfig[] = [
  {
    poolAddress: "0x5de77ccabc90b4681e83d0588fb91a54f8f70aaf", //strzr
    poolType: PoolType.REZERVE,
    gauge: "0xB33f4B9C6f0624EdeAE8881c97381837760D52CB", //lstRZR
    oracle: "0x6BDd865C63f842aa0D8b5489ad9a4a2C14A84DB9", 
    // tokens: ["0x0000000000000000000000000000000000000000"] // RZR address placeholder
  },
  {
    poolAddress: "0xC42d337861878baa4dC820D9E6B6C667C2b57e8A",
    poolType: PoolType.EULER,
    gauge: "0x0000000000000000000000000000000000000000", 
    oracle: "0x72545E019956d05ACecDB6c36cA940bcb01a84f4", 
    // tokens: ["0x0000000000000000000000000000000000000000"] // USDC address placeholder
  },
  {
    poolAddress: "0xf2d8ad2984aa8050dd1ca1e74b862b165f7a622a",
    poolType: PoolType.BALANCER,
    gauge: "0x14c80B2822c908b9Af601ccebe50124c050518CA", 
    oracle: "0xdefB54eA6F264b3259Eff8Ce415D3F7746c0bF3A", 
    // tokens: ["0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"] // RZR, wstETH address placeholders
  },
  {
    poolAddress: "0x3f89f8c0e0ffdfae0b97959303831fa893f1cfe0",
    poolType: PoolType.BALANCER,
    gauge: "0x320216774426B2765C72AB1ea9606D1474adF677", 
    oracle: "0x3A3C9D178D2373C96A418cbBC1b47D44BD24cdd1", 
    // tokens: ["0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"] // RZR, weETH address placeholders
  },
  {
    poolAddress: "0xecd03277a21e41bd61c9226eba24930a6a54b30c",
    poolType: PoolType.BALANCER,
    gauge: "0x69BD054863DbF43a42189665dBD4060d2C07A2C8", 
    oracle: "0x7FE732b26150F82058d9Ccb9ec1DeCF0078f088f", 
    // tokens: ["0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"] // RZR, lstRZR address placeholders
  },
  {
    poolAddress: "0xc2fcdd48209dd383b1f2ac120b84b2a75ee18bd3",
    poolType: PoolType.CURVE,
    gauge: "0x92Acebc0a18B9aCdd67B2813F8B10c5992c7d78b", 
    oracle: "0x6F644b44B47c47f90b758FBAbE097F582bA67Aa3", 
    // tokens: ["0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"] // RZR, frxETH, crvUSD address placeholders
  },
  {
    poolAddress: "0xaa38D5755d313f03390Dce8b570fB01Cc591DfFd",
    poolType: PoolType.UNISWAP,
    gauge: "0x0000000000000000000000000000000000000000", 
    oracle: "0x5D4Dcae73261C02Ae1bFfC24056bC809608F5137", 
    // tokens: ["0x0000000000000000000000000000000000000000", "0x0000000000000000000000000000000000000000"] // RZR, ETH address placeholders
  }
];

// Network-specific configurations
const networkConfigs: { [key: string]: NetworkConfig } = {
  "sonic": {
    rzrOracle: "0xd38199e00905062C0953E1DA403D1c748af066A1",
    pools: SonicFarmingPoolData,
  },
  "mainnet": {
    rzrOracle: "0x6BDd865C63f842aa0D8b5489ad9a4a2C14A84DB9",
    pools: MainnetFarmingPoolData,
  },
};



// Function to get complete network configuration
function getNetworkConfig(network?: string): NetworkConfig | null {
  if (!network) {
    return null;
  }
  
  const normalizedNetwork = network.toLowerCase();
  return networkConfigs[normalizedNetwork] || null;
}



export {  
  SonicFarmingPoolData, 
  MainnetFarmingPoolData, 
  getNetworkConfig,
  PoolType,
  type PoolConfig,
  type NetworkConfig,
};