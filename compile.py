import os

SHADERS = {
    "global_lighting" : [
        {"defines" : []},
        {"defines" : ["HQ"]},
        {"defines" : ["PRERELEASE"]},
        {"defines" : ["PRERELEASE", "HQ"]},
    ],
    "omni" : [
        {"defines" : ["HQ"]},
        {"defines" : ["HQ", "PROJECTION"]},
        {"defines" : ["HQ", "SPECULAR"]},
        {"defines" : ["HQ", "PROJECTION", "SPECULAR"]},
        {"defines" : ["PRERELEASE", "HQ"]},
        {"defines" : ["PRERELEASE", "HQ", "PROJECTION"]},
        {"defines" : ["PRERELEASE", "HQ", "SPECULAR"]},
        {"defines" : ["PRERELEASE", "HQ", "PROJECTION", "SPECULAR"]},
    ],
    "spot" : [
        {"defines" : []},
        {"defines" : ["HQ", "PROJECTION"]},
        {"defines" : ["HQ", "SPECULAR"]},
        {"defines" : ["HQ", "PROJECTION", "SPECULAR"]},
        {"defines" : ["PRERELEASE"]},
        {"defines" : ["PRERELEASE", "HQ", "PROJECTION"]},
        {"defines" : ["PRERELEASE", "HQ", "SPECULAR"]},
        {"defines" : ["PRERELEASE", "HQ", "PROJECTION", "SPECULAR"]},
        {"path" : "spot.default.INVSQ.orig", "defines" : ["INVSQ"]},
        {"path" : "spot.default.HQ.INVSQ.PROJECTION.orig", "defines" : ["HQ", "INVSQ", "PROJECTION"]},
        {"path" : "spot.default.HQ.INVSQ.PROJECTION.SPECULAR.orig", "defines" : ["HQ", "INVSQ", "PROJECTION", "SPECULAR"]},
        {"path" : "spot.default.HQ.INVSQ.SPECULAR.orig", "defines" : ["HQ", "INVSQ", "SPECULAR"]},
    ],
    "post_contour_mask" : [
        {"defines" : []},
        {"defines" : ["PDTH"]},
    ],
}

for shader, passes in SHADERS.items():
    for shaderpass in passes:
        path = shaderpass.get("path") or shader
        infile = f"{path}.hlsl"

        outfile = f"out/{shader}.default"
        for define in shaderpass["defines"]:
            outfile += f".{define}"

        outfile += ".cso"
        
        command = f"fxc.exe /T ps_5_0 /nologo {infile} /Fo {outfile}"
        for define in shaderpass["defines"]:
            command += f" /D {define}"

        print(command)
        os.system(command)