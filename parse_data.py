import argparse
import os
import pandas as pd

def parse_file(fname: str):
    if not os.path.isfile(fname):
        print(f"the following path is not a valid file: {fname}")
        return None
    df = pd.read_csv(fname, usecols=["counter value", "event name"])
    df = df.set_index("event name").T
    parent_dir, basename = fname.split("/")[-2:]
    head, sep, tail = basename.partition(".csv")
    df.reset_index(drop=True, inplace=True)
    df["benchmark"] = parent_dir
    insns = head.split("_")
    assert(len(insns) == 4 or len(insns) == 8) # 8 is for ifconvert-dep
    if len(insns) == 4:
        df["first instruction"] = "_".join([insns[0], insns[1]])
        df["second instruction"] = "_".join([insns[2], insns[3].split("-")[0]])
    else:
        df["first instruction"] = "_".join([insns[0], insns[1]])
        df["second instruction"] = "_".join([insns[2], insns[3]])
        df["third instruction"] = "_".join([insns[4], insns[5]])
        df["fourth instruction"] = "_".join([insns[6], insns[7].split("-")[0]])

    df["file name"] = head
    return df

def parse_directory(dname: str):
    raw_data = [parse_file(os.path.join(dname, f)) for f in os.listdir(dname)]
    filtered_raw_data = [data for data in raw_data if data is not None]
    if filtered_raw_data == []:
        return None
    aggregate_data = pd.concat(filtered_raw_data, ignore_index=True)
    print(aggregate_data)
    return aggregate_data

def parse_arguments():
    parser = argparse.ArgumentParser(description="Parse data logs")
    parser.add_argument(
        "-regen",
        "--regen-aggregate",
        action="store_true",
        help="Regenerate aggregate data table",
    )
    return parser.parse_args()

def main():
    args = parse_arguments()
    for file in os.listdir("./data"):
        fname = os.path.join("./data", file)
        if os.path.isdir(fname):
            if os.path.isfile(f"{fname}.csv") and not args.regen_aggregate:
                continue
            print(f"parsing {fname}")
            data = parse_directory(fname)
            if data is not None:
                data.drop(data.columns[6], axis=1, inplace=True)
                data.to_csv(f"{fname}.csv")

if __name__ == "__main__":
    main()
