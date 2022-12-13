try:
    from bitstring import BitArray
except:
    raise Exception(
        "Missing a library, try `sudo apt install python3-bitstring`"
    )


class LineException(Exception):
    pass
