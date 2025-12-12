import { Address, Cell, beginCell, toNano } from '@ton/core';
import { NetworkProvider } from '@ton/blueprint';
import { Distribution } from '../build/Distribution/Distribution_Distribution';
import { sign } from 'tweetnacl';

export async function run(provider: NetworkProvider, args: string[]) {
    const contractAddress = "kQBARy5fi13eWETLrwxFCw8FRg5wMa01tQR6eckN95nvnB1X"

    const address = Address.parse(contractAddress);

    const distribution = provider.open(Distribution.fromAddress(address));

    const privateKey = "58da52d9236a72e2dfaf7b1dee0cae2c8f5f5db303332aa7c5646fc39b08d9cc2205c9e4cd8e7269a0bd6b3d2cf09e5ea98707f5e39c3090c6d72a15f96ad15d"

    const secretKey = new Uint8Array(Buffer.from(privateKey, "hex"));

    const balance = BigInt(200000 * 1e9);
    const beneficiary = Address.parse("0QBj_AHTADo6OpY6aR5xnWFTdfAl9PlA1xhPT2jwWTMv6G-I");
    const nonce = BigInt(Math.floor(Date.now()));
    const expiredAt = BigInt(Math.floor(Date.now() / 1000) + 300);

    // const nonce = 1765573724300n;
    // const expiredAt = 1765574024n;

    const signCell = (cell: Cell) => {
        const hash = cell.hash();
        const sig = sign.detached(hash, secretKey);
        return Buffer.from(sig);
    };

    const signedDataCell = beginCell()
        .storeCoins(balance)
        .storeAddress(beneficiary)
        .storeUint(nonce, 64)
        .storeUint(expiredAt, 64)
        .endCell();

    const sigBuf = signCell(signedDataCell);

    console.log(nonce)
    console.log(expiredAt)

    await distribution.send(
        provider.sender(),
        {
            value: toNano('0.1'),
        },
        {
            $$type: 'Claim',
            signature: sigBuf,
            signedData: signedDataCell.beginParse()
        }
    );
}
