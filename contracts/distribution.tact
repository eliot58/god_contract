struct JettonWalletStateInit {
    balance: Int as coins = 0;
    owner: Address;
    master: Address;
    jettonWalletCode: Cell;
}

message(0xf8a7ea5) JettonTransfer {
    queryId: Int as uint64;
    amount: Int as coins;
    destination: Address;
    responseDestination: Address?;
    customPayload: Cell?;
    forwardTonAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

message(0xae37766f) DistributionInit {
    pub: Int as uint256;

    jettonMinterAddress: Address;
    jettonWalletCode: Cell;
}

message(0xbc7b9b61) Claim {
    signature: Slice as bytes64;
    signedData: Slice;
}

message(0x5d2eb348) ClearNonces {}
message(0x2365d020) Withdraw {}

message(0xd53276db) Excesses {}

inline fun sendJettons(
    receiver: Address,
    amount: Int,
    minterAddress: Address,
    jettonWalletCode: Cell,
) {
    let thisContractJettonWallet = calculateJettonWalletAddress(
        myAddress(),
        minterAddress,
        jettonWalletCode,
    );

    message(MessageParameters {
        to: thisContractJettonWallet,
        value: ton("0.05"),
        body: JettonTransfer {
            queryId: 0,
            amount,
            destination: receiver,
            responseDestination: myAddress(),
            customPayload: null,
            forwardTonAmount: 0,
            forwardPayload: beginCell().storeMaybeRef(null).asSlice(),
        }.toCell(),
    });
}

inline fun calculateJettonWalletAddress(
    owner: Address,
    minterAddress: Address,
    jettonWalletCode: Cell,
): Address {
    let initData = getJettonWalletStateInit(owner, minterAddress, jettonWalletCode);
    return contractAddress(StateInit { code: jettonWalletCode, data: initData });
}

inline fun getJettonWalletStateInit(
    owner: Address,
    minterAddress: Address,
    jettonWalletCode: Cell,
): Cell {
    return JettonWalletStateInit {
        owner,
        master: minterAddress,
        jettonWalletCode,
    }.toCell();
}

contract Distribution {

    const MaxMapSize: Int = 3000;

    owner: Address;
    pub: Int as uint256;
    jettonMinterAddress: Address;
    jettonWalletCode: Cell;
    nonces: map<Int as uint64, Int as uint64>;
    noncesCount: Int as uint64;

    init(msg: DistributionInit) {
        self.owner = sender();
        self.pub = msg.pub;
        self.jettonMinterAddress = msg.jettonMinterAddress;
        self.jettonWalletCode = msg.jettonWalletCode;
        self.nonces = emptyMap();
        self.noncesCount = 0;
    }

    receive() {}

    receive(msg: Claim) {
        require(context().value >= ton("0.1"), "Min 0.1 TON to create");

        require(checkSignature(msg.signedData.hash(), msg.signature, self.pub), "Invalid bundle");

        let amount: Int = msg.signedData.loadCoins();
        let beneficiary = msg.signedData.loadAddress();
        let nonce = msg.signedData.loadUint(64);
        let expiredAt = msg.signedData.loadUint(64);

        require(self.MaxMapSize > self.noncesCount, "Max nonces count reached");
        require(now() < expiredAt, "payload expired");
        require(beneficiary == sender(), "payload not for sender");
        require(!self.nonces.exists(nonce), "nonce already used");

        self.nonces.set(nonce, expiredAt);
        self.noncesCount += 1;

        sendJettons(
            beneficiary,
            amount,
            self.jettonMinterAddress,
            self.jettonWalletCode,
        );
    }

    receive(msg: ClearNonces) {
        foreach (key, value in self.nonces) {
            let _ = self.nonces.del(key);
            self.noncesCount -= 1;
        }
    }

    receive(msg: Withdraw) {
        require(self.owner == sender(), "Only owner");

        message(MessageParameters {
            to: self.owner,
            value: myBalance(),
            body: ("Factory: withdraw").asComment()
        });
    }

    receive(msg: Excesses) { }

    get fun getNoncesLength(): Int {
        return self.noncesCount;
    }
}
