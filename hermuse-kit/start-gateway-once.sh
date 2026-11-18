#!/bin/bash
export no_proxy="localhost,127.0.0.1" NO_PROXY="localhost,127.0.0.1"
exec ~/.local/bin/hermes gateway run
