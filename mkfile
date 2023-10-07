< config.mk

results/%.rds: results/%.nc
	set -x
	mkdir -p `dirname $target`
	Rscript bin/rscript.R \
		--shp $SHAPE \
		--input $prereq \
		--output $target".build" \
	&& mv $target".build" $target

