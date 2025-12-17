## SolBeePop_ecotox: landscape application
## NetLogo Model Set Up & Run: adapt script for each simulation set defined by "run_*.csv" file
## Author: Amelie Schmolke 
## Adapted by: Noemie Huvelle

rm(list = ls()) # clean up workspace
library(XML) # load library
library(here)
## Commands
# cd Ouput_file sh file
# chmod +x run_scenario.sh
# ./run_scenario.sh

## Inputs ---------------------------------------------------------------------
## change those for a new set of simulations

sfp = here()# source file of the scenario csv
ofp = here("run_scenarios/Results_analysis")
mfp = here("SolBeePop_model/SolBeePop_ecotox.nlogo") # NetLogo model code
ffp = here("run_scenarios/QualityFlo_scenarios") #Floral inputs file path 
csv_in  <- file.path(sfp, 'run_scenarios_Nie2015.csv')
xml_out <- file.path(ofp, 'run_scenarios_Nie2015.xml')
sh_out  <- file.path(ofp, 'run_scenarios_Nie2015.sh')

## Set Up ---------------------------------------------------------------------
#Read csv
vdf = read.csv(csv_in, sep = ";", dec = ".", stringsAsFactors = FALSE, check.names = FALSE)
str(vdf)

## Correct the floral input path (ffp/scenario_name.csv)
vdf$input.floral <- file.path(ffp, vdf$input.floral)


#--

vls = c(  # numeric inputs to NetLogo
  'Start.day', 'Initial.num.f', 'Initial.num.m', 'Initial.age', 'RndSeed',
  'Num.repeat.yr', 'DD.thresh.s', 'DD.max.cells.s', 'DD.log.slope',
  'day.emerge.f', 'var.emerge.f', 'day.emerge.m',
  'var.emerge.m', 'latest.emerge', 'dev.egg', 'dev.larva', 'dev.cocoon',
  't.maturation', 'm.life', 'max.nesting.life', 'p.max.nesting.life',
  'max.f.ratio', 'max.cells', 'max.survival.e.f', 'max.survival.e.m',
  'emerged.survival', 'a.cell.age', 'a.sex.age', 'a.size.age',
  'a.cell.resource', 'a.sex.resource', 'a.size.resource',
  'ad.nectar.cons', 'ad.pollen.cons', 'k_CA', 'ad.ET', 'TC_soil', 'TC_leaf',
  't.guts', 'kd_SD', 'bw_SD', 'mw_SD', 'kd_IT', 'mw_IT', 'Fs_IT',
  'nectar_prop', 'weight_prov', 'SM', 'F', 'SA_i', 'dr.intercept', 'dr.slope')
# model outputs to be collected
ols = c('doy', 'year', 'DateREP', 'count turtles', 'bees.emerged.yr',
  'f.emerged.yr', 'm.emerged.yr', 'f.postemergent.today',
  'bees.nesting', 'bees.nesting.today',
  'sum.cells.today', 'sum.f.cells.today', 'sum.m.cells.today', 'sum.cells',
  'sum.f.cells', 'sum.m.cells', 'mean.cells.today', 'mean.f.cells.today',
  'mean.m.cells.today', 'mean.cells', 'mean.f.cells', 'mean.m.cells')

## Create xml and bat(.sh) files ---------------------------------------------------
bls = c()
bls <- c(
  '#!/bin/bash',
  '# Script auto-généré pour exécuter SolBeePop en headless depuis la racine',
  sprintf('PROJ_ROOT="%s"', proj_root),
  'cd "$PROJ_ROOT"  # On se place dans la racine du projet',
  '',
  'NETLOGO_HOME="/Applications/NetLogo 6.3.0"',
  'NETLOGO="$NETLOGO_HOME/netlogo-headless.sh"',
  ''
)

xls = xmlHashTree() 
nde = addNode(xmlNode('experiments'), character(), xls)

# Loop through scenarios
for(i in 1:nrow(vdf)){
  ## assign variable values
  for(j in colnames(vdf)){
    x = vdf[i,j]
    if(grepl(',', x)) x = trimws(strsplit(x, ',')[[1]])  # split list
    if(j %in% vls) x = as.numeric(x)  # format number
    assign(j, x)
    rm(x)
  }
  rm(j)
  
  ## Add to bat (.sh) file
  bls = c(bls,
          paste0(
            '"$NETLOGO"',
            ' --model "', mfp, '"',
            ' --setup-file "', xml_out, '"',
            ' --experiment ', i,
            ' --table "', file.path(ofp, paste0(name, ".csv")), '"'
          )
  )
  
  ## Add to xml file
  snde = addNode(xmlNode('experiment',  # scenario name
    attrs = c(name = i, repetitions = '1', 
      runMetricsEveryStep = 'true')), nde, xls)
  tnde = addNode(xmlNode('setup'), snde, xls)  # set up
  addNode(xmlTextNode('setup'), tnde, xls)
  tnde = addNode(xmlNode('go'), snde, xls)  # go
  addNode(xmlTextNode('go'), tnde, xls)
  # addNode(xmlNode('timeLimit', attrs = c(steps = 365*2)), snde, xls)  # steps
  for(j in ols){
    tnde = addNode(xmlNode('metric'), snde, xls)
    addNode(xmlTextNode(j), tnde, xls)
  }
  rm(j)

  for(j in colnames(vdf)){  # input values
    if(j == 'name') next
    tnde = addNode(xmlNode('enumeratedValueSet', 
      attrs = c(variable = j)), snde, xls)
    for(k in get(j)) {
      if(class(k) == 'character' | is.na(k)){
        k = paste0('\"', k, '\"')
      } else if(class(k) == 'logical'){
        k =  tolower(k)
      }
      addNode(xmlNode('value', attrs = c(value = k)), tnde, xls)
    }
    rm(k)
  }
  rm(j)
}

# write xml file
write('<?xml version="1.0" encoding="UTF-8"?>', file = xml_out)
write('<!DOCTYPE experiments SYSTEM "behaviorspace.dtd">',
  file = xml_out, append = TRUE)
capture.output(xls, file = xml_out, append = TRUE)

#Write bash script
writeLines(bls, sh_out)

#Rendre le script exécutable depuis R
Sys.chmod(sh_out, mode = "0755")

rm(list = ls()) # clean up workspace

