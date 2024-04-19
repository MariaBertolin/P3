#!/bin/bash

# Establecemos que el código de retorno de un pipeline sea el del último programa con código de retorno
# distinto de cero, o cero si todos devuelven cero.
set -o pipefail

# Definimos los valores a iterar para cada parámetro
m_values=($(seq 1 1 1))                             # -m: Longitud del filtro de mediana
c_values=($(seq 0.0073 0.000001 0.0073))            # -c: Multiplicador máximo de recorte
r_values=($(seq 0.39 0.00001 0.39))                 # -r: Umbral máximo de la segunda autocorrelación normalizada
l_values=($(seq 0.545 0.0001 0.545))                # -1: Umbral de relación de autocorrelación r[1]/r[0]
z_values=($(seq 2500 0.1 2500))                     # -z: Umbral de tasa de cruce por cero
p_values=($(seq -52.1 0.1 -52.1))                   # -p: Umbral de potencia

# Calculamos el número total de iteraciones
total_iterations=$(( ${#m_values[@]} * ${#c_values[@]} * ${#r_values[@]} * ${#l_values[@]} * ${#z_values[@]} * ${#p_values[@]} ))
current_iteration=0

max_score=0

# Bucle para iterar sobre los diferentes valores
for m in "${m_values[@]}"; do
    for c in "${c_values[@]}"; do
        for r in "${r_values[@]}"; do
            for l in "${l_values[@]}"; do
                for z in "${z_values[@]}"; do
                    for p in "${p_values[@]}"; do
                        # Construimos el comando GETF0 con los valores actuales
                        GETF0="get_pitch -m $m -c $c -r $r -1 $l -z $z -p $p"
                    
                        # Calculamos el porcentaje de ejecución
                        ((current_iteration++))
                        percentage=$(( (current_iteration * 100) / total_iterations ))
                    
                        # Ejecutamos el comando para calcular FS
                        for fwav in pitch_db/train/*.wav; do
                            ff0=${fwav/.wav/.f0}
                            echo -ne "Progreso: $percentage% - Ejecutando: $GETF0 $fwav $ff0\r"
                            $GETF0 $fwav $ff0 > /dev/null || ( echo -e "\nError in $GETF0 $fwav $ff0" && exit 1 )
                        done

                        # Calculamos el puntaje total
                        pitch_evaluate pitch_db/train/*.f0ref | grep "===>	TOTAL:" | awk '{print $3}' > salida_final.txt
                        FS=$(<salida_final.txt)

                        # Actualizamos el valor máximo y guardamos los parámetros correspondientes
                        if (( $(echo "$FS > $max_score" | bc -l) )); then
                            max_score=$FS
                            best_params="-m $m -c $c -r $r -1 $l -z $z -p $p"
                        fi
                    done
                done
            done
        done
    done
done

# Imprimir los mejores parámetros y el puntaje máximo
echo -e "\nLos mejores parámetros son: $best_params"
echo "El puntaje máximo es: $max_score"

exit 0
