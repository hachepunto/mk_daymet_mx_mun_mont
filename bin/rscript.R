#!/usr/bin/env Rscript

#### analisis geolocalizacion y temperaturas máximas méxico

### abrir e instalar paquetes necesarios

#if (!require("pacman")) install.packages("pacman")

pacman::p_load(optparse, raster, sf, data.table, tidyverse, maps, janitor, 
               tictoc, future, future.apply, beepr)



option_list <- list(
    make_option(c("-s","--shp"), type="character", default=NULL            ,metavar="character" ,help="path to shape locality file"                            ),
    make_option(c("-i","--input"), type="character", default=NULL            ,metavar="character" ,help="path to input nc file"                            ),
    make_option(c("-o","--output"), type="character", default=NULL            ,metavar="character" ,help="path to output file"                            )
)

# convertir la lista de opciones a argumentos 
opt_parser <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser)

resdir <- strsplit(opt$output, split = "/")[[1]][length(strsplit(opt$output, split = "/")[[1]])-1]
plotdir <- paste0(resdir, "/plots/")

inf <- strsplit(basename(opt$input), "_")[[1]]

type <- inf[3]
periodity <- inf[4]
year <- strsplit(inf[6], "[.]")[[1]][1]

outname <- paste(type, periodity, year, sep = "_")

### paralelizar los procesos 

#plan(multisession)


### abrir archivo de localización de municipios. Este es un archivo shp que contiene los límites geográficos de México

#mx_mun = st_read(`/STORAGE/genut/dalvarez/TEMPERATURA_MEXICO_MUNICIPAL/hdx_municipes_maps/mex_admbnda_adm2_govmex_20210618.shp') %>%
mx_mun = st_read(opt$shp) %>%
  mutate(municipio = ADM2_ES,
         state     = ADM1_ES) %>%
  dplyr::select(municipio, state)

#plot(mx_mun)

### abrir archivos de datos de temperaturas máximas de Daymet



# cambia rchivo tmax tmin prcp captar año
na <- opt$input %>%
  raster::stack()

pdf(paste0(plotdir, outname, "_na.pdf"))
plot(na)
dev.off()

### el CRS de na. chat gpt me dice que si los datos no tienen un datum especificado, podría ser difícil o incluso imposible combinarlos con otros conjuntos de datos que utilizan diferentes datums

crs(na)

# pdf(paste0(plotdir, "mx_mun_", outname, ".pdf"))
# plot(mx_mun)
# dev.off()

### ahora voy a agregar el datum
# es idéntica para todos

crs(na) <- "+proj=lcc +lat_0=42.5 +lon_0=-100 +lat_1=25 +lat_2=60 +x_0=0 +y_0=0 +ellps=WGS84 +datum=WGS84 +units=m +no_defs"

### ahora se debe cambiar el CRS DE mx_mun para que puedan unirse los datos correctamente

mx_mun<- mx_mun %>%
  st_transform(crs = st_crs(na))

## ver los datos CRS
st_crs(mx_mun)


### recortar para tener únicamente los datos de México

na_crop<-raster::crop(x = na,
                                y = mx_mun)

mun <- raster::mask(x = na_crop,
                              mask = mx_mun)

## ahora dibujo los mapas de temperatura máxima mensual para el año 2008

pdf(paste0(plotdir, outname, "_mx_mun.pdf"))
plot(mx_mun)
dev.off()


### ahora extraigo los datos a un dataframe

mun_extract<- raster::extract(
  x = mun, ## valores de temperatura máxima
  y = mx_mun, ## ubicaciones de los municipios
  fun = mean, ##calcular el valor promedio de las temperaturas máximas de cada municipio
  na.rm = TRUE, ##eliminar NA antes de calcular la estadística
  sp = TRUE) ## el resultado es un objeto espacial


#### dataframe para temperatura máxima mensual promedio para cada municipio

mun_extract <- mun_extract %>%
  st_as_sf() %>%  ## convierto el objeto espacial a objeto sf (simple features)
  st_drop_geometry() ## se elimina información geométrica de los datos y solo se va a mantener datos de temperatura máxima


### generar dataframe con datos de temperatura máxima para cada mes por municipio
### long format

mun_extract_final <- pivot_longer(mun_extract,
                                     cols = starts_with(paste0("X",year)),
                                     names_to  = "month",
                                     names_prefix = paste0("X",year,"."),
                                     values_to = paste0(type,"_avg")) %>% 
  mutate(month = as.numeric(substr(month, 1, 2)),
         year = year)


#save.image("TEMPERATURA_MAXIMA.RData")

saveRDS(object = mun_extract_final, file = opt$output)

