# Update to new Sirius version for Linux 64bit

1. Remove the old Sirius files from `Linux/64bit/Sirius`.

2. Download SIRIUS+CSI:FingerID Command-Line Interface only from [the official website](https://bio.informatik.uni-jena.de/software/sirius/) as a .zip file for Linux 64bit.

3. Extract the content in the `Linux/64bit/Sirius` directory.

4. Place the `sirius` start up script (from the `Linux/64bit/Sirius/bin` directory) in `Linux/64bit/Sirius`.

5. Edit the `sirius` start up script line ```cd "`dirname \"$PRG\"`/.." >/dev/null``` to ```cd "`dirname \"$PRG\"`" >/dev/null```

6. Move the `.jar` files from `Linux/64bit/Sirius/lib/app` to `All/Sirius/app`.
