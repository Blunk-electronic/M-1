#!/usr/bin/env bash

BASE_DIR="../.."

DFLT_EPF_PATH="."
DFLT_LBR_PATH="$BASE_DIR/lbr_eagle/lbr/misc:$BASE_DIR/lbr_eagle/lbr/passive:$BASE_DIR/lbr_eagle/lbr/active"
DFLT_SCR_PATH="$BASE_DIR/lbr_eagle/scr"
DFLT_ULP_PATH="$BASE_DIR/lbr_eagle/ulp"
DFLT_CAM_PATH="$BASE_DIR/lbr_eagle/cam"
DFLT_DRU_PATH="$BASE_DIR/lbr_eagle/dru"

EAGLERC="eagle.rc"
EAGLEEPF="eagle.epf"
EAGLEBIN=$(which eagle)

if [ ! -x ${EAGLEBIN} ]; then
	echo "ERROR:$(basename $0):$LINENO: Missing Eagle binary."
	exit 1
fi

if [ ! -f ${EAGLEEPF}.in ]; then
	echo "ERROR:$(basename $0):$LINENO: Missing input file: ${EAGLEEPF}.in"
	exit 1
fi

# create a blank template if we have no rc file
if [ ! -f ${EAGLERC} ]; then
	cat > ${EAGLERC} << EOF
Directories.IgnoreNonExisting = ""
Directories.Epf = ""
Directories.Lbr = ""
Directories.Scr = ""
Directories.Ulp = ""
Directories.Cam = ""
Directories.Dru = ""
Option.AutoSetRouteWidthAndDrill = "0"
EOF
fi

# set the project defaults to rc file
sed -i -e "s%\(^.*Directories.IgnoreNonExisting.*=\).*$%\1 \"1\"%" ${EAGLERC}
sed -i -e "s%\(^.*Directories.Epf.*=\).*$%\1 \"${DFLT_EPF_PATH}\"%" ${EAGLERC}
sed -i -e "s%\(^.*Directories.Lbr.*=\).*$%\1 \"${DFLT_LBR_PATH}\"%" ${EAGLERC}
sed -i -e "s%\(^.*Directories.Scr.*=\).*$%\1 \"${DFLT_SCR_PATH}\"%" ${EAGLERC}
sed -i -e "s%\(^.*Directories.Ulp.*=\).*$%\1 \"${DFLT_ULP_PATH}\"%" ${EAGLERC}
sed -i -e "s%\(^.*Directories.Cam.*=\).*$%\1 \"${DFLT_CAM_PATH}\"%" ${EAGLERC}
sed -i -e "s%\(^.*Directories.Dru.*=\).*$%\1 \"${DFLT_DRU_PATH}\"%" ${EAGLERC}
sed -i -e "s%\(^.*Option\.AutoSetRouteWidthAndDrill.*=\).*$%\1 \"1\"%" ${EAGLERC}

# copy and set the project default file in all EPF folders
for epfdir in ${DFLT_EPF_PATH//:/ }; do
	if [ ! -f ${epfdir}/${EAGLEEPF} ]; then
		cp -f ${EAGLEEPF}.in ${epfdir}/${EAGLEEPF}
	fi
done

echo "CALL:$(basename $0):$LINENO: ${EAGLEBIN} -U ${EAGLERC} ${@}"
exec ${EAGLEBIN} -U ${EAGLERC} ${@}
