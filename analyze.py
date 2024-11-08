import argparse
import os
import io
import numpy as np
import pandas as pd
import re


def add_values(df: pd.DataFrame):
    df["IPC"] = df["instructions"] / df["cycles"]
    df["CPI"] = df["cycles"] / df["instructions"]
    return df

def get_combination_matrix(df: pd.DataFrame, value: str):
    df = df.pivot(index="first instruction", columns="second instruction", values=value)
    return df

def get_lower_triangular_combination_matrix(df: pd.DataFrame, value: str):
    df = df.pivot(index="first instruction", columns="second instruction", values=value)
    lower_triangular = np.tril(df.values)
    upper_triangular = np.triu(df.values)
    lower_triangular_df = pd.DataFrame(lower_triangular, columns=df.columns, index=df.index).T
    upper_triangular_df = pd.DataFrame(upper_triangular, columns=df.columns, index=df.index)
    result = upper_triangular_df.combine_first(lower_triangular_df).T
    return result

def get_minimal_insn_info(df: pd.DataFrame):
    df = df[df["first instruction"] == df["second instruction"]]
    df = df[["first instruction", "IPC"]]
    df.reset_index(drop=True, inplace=True)
    return df

def latex_table_to_df(latex: str):
    reduced_str = "\n".join(latex.split("\n")[1:-2])
    reduced_str = re.sub(" & ", ",", reduced_str)
    reduced_str = re.sub("\\\color#[a-f0-9]{6} ", "", reduced_str)
    reduced_str = re.sub("\\\\", "", reduced_str)
    reduced_str = re.sub("(background-color#[a-f0-9]{6} [^\n,]+)", "$\\1$", reduced_str)
    reduced_str = re.sub(" \\$", "$", reduced_str)
    print(reduced_str[-100:])
    reduced_str = re.sub("background-color(#[a-f0-9]{6}) ", "\\\color{\\1}", reduced_str)
    style_df = pd.read_table(io.StringIO(reduced_str), sep=",")
    return style_df

def get_stylized_markdown(df:pd.DataFrame, fname:str):
    styled_df = df.style.background_gradient(axis=None, cmap="Greens")
    latex_string = styled_df.to_latex()
    styled_df = latex_table_to_df(latex_string)
    styled_df.to_markdown(f"{fname}")


def get_caption(fname: str):
    base = fname.split("/")[-1]
    file = base.split(".")[0]
    latency = "-dep" in file
    category = file.split("-")[:-2] if latency else file.split("-")[:-1]
    return f"{' '.join(category).title()} {'Latency' if latency else 'Throughput'} (IPC)"

def create_index(save_path: str):
    index_str = """
<html>
 <head>
   <title>Banana Pi Microprobe Tables</title>
 </head>
 <body>
   <h1>Tables</h1>
   <div>
     <ul>
       <li><a href="./i-results.html">Integer Op Throughput</a></li>
       <li><a href="./i-dep-results.html">Integer Op Latency</a></li>
       <li><a href="./f-results.html">Floating Op Throughput</a></li>
       <li><a href="./f-dep-results.html">Floating Op Latency</a></li>
     </ul>
   </div>
 </body>
 </html>
    """
    with open(f"{save_path}/index.html", "w") as f:
        f.write(index_str)

def save_table_as_html(df: pd.DataFrame, fname: str):
    styled_df = df.style.background_gradient(axis=None, cmap="Greens")
    styled_df.set_caption(get_caption(fname))
    styled_df.set_table_styles(
        [
            {
                'selector': 'th.col_heading',
                'props': 'text-align: center; padding: 5px 5px'
            },
            {
                'selector': 'th.row_heading',
                'props': 'text-align: left; padding: 5px 5px'
            },
            {
                'selector': 'th:not(.index_name)',
                'props': 'border: 1px solid #000000;'
            },
            {
                'selector': 'td',
                'props': 'text-align: center;'
            },
            {
                'selector': 'caption',
                'props': 'font-size: 2em;'
            },
        ]
    )
    styled_df.set_table_attributes('style="border-collapse: collapse"')
    table_html = styled_df.to_html()
    with open(fname, "w") as f:
        f.write(table_html)

def parse_arguments():
    parser = argparse.ArgumentParser(description="Generate tables")
    parser.add_argument(
        "--save-html-path",
        type=str,
        default=None,
        help="Path to save html",
    )
    return parser.parse_args()

def main():
    args = parse_arguments()
    categories = []
    read_dfs = {}
    for file in os.listdir("./data"):
        fname = os.path.join("./data", file)
        # skip directories
        if os.path.isfile(fname) and ".csv" in fname:
            # skip f2i and i2f indirect converts
            if fname == "./data/ifconvert-dep-results.csv":
                print(f"skipping {fname}")
                continue
            fid, sep, tail = file.partition(".csv")
            if "dep" not in file:
                category, sep, tail = fid.partition("-results")
                categories.append(category)

            df = pd.read_csv(fname)
            df = add_values(df)
            read_dfs[fid] = df

            result = None
            # get combination matrix
            if ("i2f" in fname
                or "f2i" in fname
                or "ifconvert" in fname):
                result = get_combination_matrix(df, "IPC")
                print(f"{fname} getting regular combination")
            else:
                print(f"{fname} triangular")
                result = get_lower_triangular_combination_matrix(df, "IPC")
            fname, sep, tail = fname.partition(".csv")
            if args.save_html_path is not None:
                create_index(args.save_html_path)
                save_table_as_html(result, f"{fname.replace('./data', args.save_html_path)}.html")
            # get_stylized_markdown(result, f"{fname}-styled.md")
            result.to_markdown(f"{fname}.md")

    # Do throughput latency comparison
    for category in categories:
        if f"{category}-results" not in read_dfs or f"{category}-dep-results" not in read_dfs:
            continue
        throughput = read_dfs[f"{category}-results"]
        throughput = get_minimal_insn_info(throughput).rename(
            columns={"first instruction": "insn", "IPC": "throughput IPC"}
        )
        latency = read_dfs[f"{category}-dep-results"]
        latency = get_minimal_insn_info(latency)

        combined = throughput
        combined["latency IPC"] = latency["IPC"]
        combined.to_markdown(f"./data/{category}-throughput-latency.md")


if __name__ == '__main__':
    main()

