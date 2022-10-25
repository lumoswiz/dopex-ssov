import argparse
from eth_abi import encode_single
import pandas as pd


def main(args):
    if args.type == "epoch":
        get_inputs(args)


def get_inputs(args):
    df = pd.read_csv("analysis/input.csv")
    epoch = df.iloc[args.index]["epoch"]
    blockNumber = df.iloc[args.index]["blockNumber"]
    strikeIndex = df.iloc[args.index]["strikeIndex"]
    amount = df.iloc[args.index]["amount"]
    txType = df.iloc[args.index]["txType"]

    # convert amount to wei
    amount *= 10 ** 18

    enc_e = encode_single("uint256", int(epoch))
    enc_b = encode_single("uint256", int(blockNumber))
    enc_s = encode_single("uint256", int(strikeIndex))
    enc_a = encode_single("uint256", int(amount))
    enc_t = encode_single("bool", bool(txType))

    ## prepend 0x for FFI parsing
    print("0x" + enc_e.hex() + enc_b.hex() + enc_s.hex() + enc_a.hex() + enc_t.hex())


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("type")
    parser.add_argument("--index", type=int)
    return parser.parse_args()


if __name__ == "__main__":
    args = parse_args()
    main(args)
