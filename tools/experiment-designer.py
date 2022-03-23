import argparse

from doepy import build, read_write

design_types = {
    # 'full': build.full_fact,
    # 'fractional': build.frac_fact_res,
    # 'plackett-burman': build.plackett_burman,
    # 'box-behnken': build.box_behnken,
    "lhs": build.lhs,
    "lhs-space-filling": build.space_filling_lhs,
    "k-means": build.random_k_means,
    "maximin": build.maximin,
    "halton": build.halton,
    "uniform": build.uniform_random,
    "sukharev": build.sukharev,
}


def prepare(ranges, design, n):
    # TODO implement design methods with different function signatures
    if design in design_types:
        return design_types[design](ranges, num_samples=n)
    else:
        raise NotImplementedError(f"Design {design} is not implemented")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        "experiment-designer",
        description="Create a Design of Experiment for USEPE-BlueSky",
    )
    parser.add_argument(
        "samples",
        help="Number of points to sample in the input space",
        type=int,
        metavar="n",
    )
    parser.add_argument(
        "--type",
        dest="design_type",
        help="Type of the design to be created (defaults to 'lhs')",
        type=str,
        default="lhs",
        choices=design_types.keys(),
    )
    parser.add_argument(
        "--input",
        dest="input",
        help="Path to the input file that holds the variable ranges (defaults to 'scenario/experiment-variables.csv')",
        type=str,
        default="scenario/experiment-variables.csv",
    )
    parser.add_argument(
        "--output",
        dest="output",
        help="Path to the output file that holds the design (defaults to 'scenario/experiment-design.csv')",
        type=str,
        default="scenario/experiment-design.csv",
    )
    args = parser.parse_args()

    ranges = read_write.read_variables_csv(args.input)
    doe = prepare(ranges, args.design_type, args.samples)
    read_write.write_csv(doe, args.output)
