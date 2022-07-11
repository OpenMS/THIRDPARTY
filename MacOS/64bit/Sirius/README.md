# Update to new Sirius version for MacOS

1. Remove the old Sirius files from `MacOS/64bit/Sirius`.

2. Download SIRIUS+CSI:FingerID Command-Line Interface only from [the official website](https://bio.informatik.uni-jena.de/software/sirius/) as a .zip file for MacOS 64bit.

3. Extract the content from `sirius.app/Contents` in the `MacOS/64bit/Sirius` directory.

4. Place the `sirius` start up script (from the `MacOS/64bit/Sirius/MacOS` directory) in `MacOS/64bit/Sirius`.

5. Edit the `sirius` start up script line *cd "`dirname \"$PRG\"`/.." >/dev/null* to *cd `dirname \"$PRG\"` >/dev/null*

6. Move the `.jar` files from `MacOS/64bit/Sirius/app` to `All/Sirius/app`.