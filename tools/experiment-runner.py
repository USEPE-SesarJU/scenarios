"""
    External client for BlueSky that exposes a simple way to load scenario files.

    When you run this file, make sure python knows where to find BlueSky (see args)
"""
import argparse
import logging
import os
import sys
import tempfile

import pandas as pd

logger = logging.getLogger()
handler = logging.StreamHandler()
handler.setFormatter(logging.Formatter("%(asctime)s %(name)-12s %(levelname)-8s %(message)s"))
logger.addHandler(handler)
logger.setLevel(logging.INFO)


def main(bspath, scenario_file, doe_file):

    sys.path.append(bspath)
    from bluesky.network.client import Client

    class NetClient(Client):
        def __init__(self, scn):
            super().__init__()
            self.scenario = scn

        def event(self, name, data, sender_id):
            """Overridden event function to handle incoming ECHO commands."""
            logging.info(data)
            if name == b"ECHO":
                repr(data)

        def stack(self, text):
            """Stack function to send stack commands to BlueSky."""
            logger.info(f"Sending command: {text}")
            self.send_event(b"STACK", text)

        def run_experiment(self, experiment):
            # Set SEED command to be consistent between runs
            self.stack(f"SEED {sum([ord(c) for c in 'USEPE-BlueSky-Seed-'+self.scenario])}")
            new_scenario = f"#{experiment.name}\n{self.scenario}"
            for key, value in experiment.items():
                varname = f"${key}"
                if varname in new_scenario:
                    # handle variables that modify the base scenario file
                    new_scenario = new_scenario.replace(varname, str(value))
                    new_scenario = f"{new_scenario}\n# {varname} = {value}"
                else:
                    # TODO handle variables that modify the environment (e.g. by selecting a slice of wind data)
                    pass

            # Create a temporary scenario file used to run the simulation and call BlueSky
            tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".scn")
            try:
                tmp.write(new_scenario.encode())
                tmp.flush()
                self.stack(f"ECHO test")
                self.stack(f'PCALL "{tmp.name}" abs')
                input()
                # TODO wait for the scenario to finish
            finally:
                tmp.close()
                os.unlink(tmp.name)
                exit()

    logger.info(f"Parsing DoE: {doe_file}")
    with open(scenario_file, "r") as f:
        scenario = f.read()
    doe = pd.read_csv(doe_file)
    logger.info(f"Connecting to BlueSky: localhost:11000-11001")

    # Create and start BlueSky client
    bsclient = NetClient(scenario)
    bsclient.connect(event_port=11000, stream_port=11001)

    doe.apply(bsclient.run_experiment, axis="columns")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        "experiment-runner",
        description="Run a Design of Experiment for USEPE-BlueSky",
    )
    parser.add_argument(
        "--doe",
        dest="doe",
        help="Path to the input file that holds the DoE (defaults to 'scenario/experiment-design.csv')",
        type=str,
        default="scenario/experiment-design.csv",
    )
    parser.add_argument(
        "--bluesky",
        dest="bspath",
        help="Path to the folder that contains the BlueSky simulator",
        type=str,
        default="../bluesky-usepe/",
    )
    parser.add_argument(
        "scenario",
        help="Path to the input file that holds the base scenario",
        type=str,
    )
    args = parser.parse_args()

    main(args.bspath, args.scenario, args.doe)
