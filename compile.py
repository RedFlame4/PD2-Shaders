import os

SHADERS = {
    "global_lighting" : [
        {"defines" : []},
        {"defines" : ["HQ"]},
    ],
    "omni" : [
        {"defines" : ["HQ"]},
        {"defines" : ["HQ", "PROJECTION"]},
        {"defines" : ["HQ", "SPECULAR"]},
        {"defines" : ["HQ", "PROJECTION", "SPECULAR"]},
    ],
    "spot" : [
        {"defines" : []},
        {"defines" : ["HQ", "PROJECTION"]},
        {"defines" : ["HQ", "SPECULAR"]},
        {"defines" : ["HQ", "PROJECTION", "SPECULAR"]},
        {"path" : "spot.default.INVSQ.orig", "defines" : ["INVSQ"]},
        {"path" : "spot.default.HQ.INVSQ.PROJECTION.orig", "defines" : ["HQ", "INVSQ", "PROJECTION"]},
        {"path" : "spot.default.HQ.INVSQ.PROJECTION.SPECULAR.orig", "defines" : ["HQ", "INVSQ", "PROJECTION", "SPECULAR"]},
        {"path" : "spot.default.HQ.INVSQ.SPECULAR.orig", "defines" : ["HQ", "INVSQ", "SPECULAR"]},
    ],
}

for shader, passes in SHADERS.items():
    for shaderpass in passes:
        path = shaderpass.get("path") or shader
        infile = f"{path}.fx"

        outfile = f"out/{shader}.default"
        for define in shaderpass["defines"]:
            outfile += f".{define}"

        outfile += ".cso"
        
        command = f"fxc.exe /T ps_5_0 /nologo {infile} /Fo {outfile}"
        for define in shaderpass["defines"]:
            command += f" /D {define}"

        os.system(command)
        print(command)