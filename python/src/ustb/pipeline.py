"""Processing pipeline matching MATLAB pipeline.

Chains preprocess, midprocess, and postprocess steps in sequence, following
the USTB convention: preprocess -> midprocess -> postprocess.
"""

from ustb.apodization import Apodization


def _classify(proc):
    """Classify a process object as preprocess/midprocess/postprocess by its module.

    Mirrors the MATLAB +preprocess/+midprocess/+postprocess package
    convention: a class's kind is determined by which subpackage it lives in.
    """
    module = type(proc).__module__
    if module.startswith("ustb.preprocess"):
        return "preprocess"
    if module.startswith("ustb.midprocess"):
        return "midprocess"
    if module.startswith("ustb.postprocess"):
        return "postprocess"
    raise TypeError(
        f"Cannot classify process of type {type(proc).__name__}: expected a "
        "class from ustb.preprocess, ustb.midprocess, or ustb.postprocess"
    )


class Pipeline:
    """Chains processing steps, matching MATLAB pipeline.

    Example:
        pipe = Pipeline()
        pipe.channel_data = channel_data
        pipe.scan = scan
        b_data = pipe.go([DAS(), CoherentCompounding()])
    """

    def __init__(self):
        self.channel_data = None
        self.scan = None
        self.receive_apodization = Apodization()
        self.transmit_apodization = Apodization()

    def go(self, process_list=None):
        if not process_list:
            from ustb.midprocess import DAS

            midproc = DAS()
            midproc.channel_data = self.channel_data
            midproc.receive_apodization = self.receive_apodization
            midproc.transmit_apodization = self.transmit_apodization
            midproc.scan = self.scan
            return midproc.go()

        output = None
        prev_kind = None
        for i, proc in enumerate(process_list):
            kind = _classify(proc)

            if i == 0:
                if kind == "preprocess":
                    proc.input = self.channel_data
                elif kind == "midprocess":
                    proc.channel_data = self.channel_data
                    proc.receive_apodization = self.receive_apodization
                    proc.transmit_apodization = self.transmit_apodization
                    proc.scan = self.scan
                else:
                    raise ValueError(
                        "The first process in the pipeline must be either a "
                        "preprocess or a midprocess"
                    )
            else:
                if kind == "preprocess":
                    if prev_kind != "preprocess":
                        raise ValueError(
                            f"Only a preprocess can go after a preprocess: {prev_kind} -> {kind}"
                        )
                    proc.input = output
                elif kind == "midprocess":
                    if prev_kind != "preprocess":
                        raise ValueError(
                            f"Only a preprocess can go before a midprocess: {prev_kind} -> {kind}"
                        )
                    proc.channel_data = output
                    proc.receive_apodization = self.receive_apodization
                    proc.transmit_apodization = self.transmit_apodization
                    proc.scan = self.scan
                elif kind == "postprocess":
                    if prev_kind == "preprocess":
                        raise ValueError(
                            f"Found postprocess after preprocess: {prev_kind} -> {kind}"
                        )
                    proc.input = output
                    if hasattr(proc, "receive_apodization"):
                        proc.receive_apodization = self.receive_apodization
                    if hasattr(proc, "transmit_apodization"):
                        proc.transmit_apodization = self.transmit_apodization
                else:
                    raise ValueError("Unknown process type")

            output = proc.go()
            prev_kind = kind

        return output
