#!/bin/sh
#------------------------------------------------------------------------------------
# Nom du script : dump_mysql.sh
# Projet :
# Auteur : MNL
# Date de creation : 04/05/2012
# Objet : Sauvegarde via mysqldump de base MySQL
# Usage : ./dump_mysql.sh -d '<destination>' [--compress] [<option supplementaire mysql>]
# Commentaires : Necessite la configuration du fichiers ~/.my.cnf qui devra contenir le mot de passe de connexion via root ou d'un autre utilisateur
#		Il est aussi possible de fournir le user et mot de passe ou juste l'utilisateur via la ligne de commande
#------------------------------------------------------------------------------------
# Modification :
# Auteur :
# Date :
#------------------------------------------------------------------------------------

set -x -v

# Variable personalisable
COMPRESS=0
DATE_BACKUP="$(date "+%d%m%Y_%H%M")"
PREFIX_NAME="mysql_database_"
MESG="de sauvegarde MySQL de $(hostname)"

# Initialisation variable
CR=0

# Declaration de la fonction usage
usage()
{
	printf "Usage : ${0} -d '<destination>' [--compress]\n"
	fin_script 1
}

# Fonction fin_script
fin_script()
{
	CODE_RETOUR=$1
	printf "Fin ${MESG} - CODE RETOUR = ${CODE_RETOUR}\n"
	exit ${CODE_RETOUR}
}

# Fonction check_compress
check_compress()
{
	NAME_FILE=$2
	if [ ${1} -eq 0 ]
	then
		if [ ${COMPRESS} -eq 1 ]
		then
			gzip ${NAME_FILE}
			if [ ${?} -ne 0 ]
			then
				printf "Echec de la compression de ${NAME_FILE}\n"
				return 2
			fi
		fi
	else
		printf "Echec de la sauvegarde de ${NAME_FILE}\n"
		return 1
	fi
}

# Controle des variables fournit au script
while [ "x${1}" != "x" ]
do
	case ${1} in
		-d)
			DEST=${2}
			shift
			;;
		--compress)
			COMPRESS=1
			;;
		*)
			MYSQL_PARAM="${MYSQL_PARAM} $1"
			;;
	esac
	shift
done

printf "Debut ${MESG}\n"

# Controle la disponibilite commande mysql, mysqldump
for i in mysql mysqldump
do
	which ${i} > /dev/null 2>&1
	if [ $? -ne 0 ]
	then
		printf "Impossible de trouver le binaire ${i}\n"
		fin_script 254
	fi
done

# Controle que DEST est initialise
if [ "x${DEST}" = "x" ]
then
	printf "le parametre -d n'a pas ete fournit\n"
	fin_script 253
fi

# Verifie que le repertoire de destination soit accessible
if [ ! -d ${DEST} ]
then
	printf "Le repertoire ${DEST} n'est pas disponible\nCreation du repertoire\n"
	mkdir -p ${DEST}
	if [ $? -ne 0 ]
	then
		printf "Erreur lors de la creation de ${DEST}\n"
		fin_script 252
	fi
fi

touch ${DEST}/test_fichiers_$$ > /dev/null 1>&2
if [ $? -ne 0 ]
then
	printf "Erreur, le repertoire ${DEST} n'est pas accessible en ecriture\n"
	fin_script 251
else
	rm ${DEST}/test_fichiers_$$
fi

# Controle la connexion a MySQL
mysql ${MYSQL_PARAM} --batch -e "show databases;" > /dev/null 2>&1
if [ $? -ne 0 ]
then
	printf "Erreur lors de la connexion a la base mysql\n"
	fin_script 252
fi

# Lance la sauvegarde sur l'ensemble du perimetre via parametre "--all-databases"
mysqldump ${MYSQL_PARAM} --opt --events --routines --triggers --all-databases --lock-tables --log-error=${DEST}/${PREFIX_NAME}all_${DATE_BACKUP}.err > ${DEST}/${PREFIX_NAME}all_${DATE_BACKUP}.sql
check_compress ${?} ${DEST}/${PREFIX_NAME}all_${DATE_BACKUP}.sql
CR=$(expr $? + ${CR})

# Pour chaque bases disponibles
for i in $(mysql ${MYSQL_PARAM} -B -N -e "show databases;")
do
	case x${i} in
		xperformance_schema)
			continue
			;;
		xinformation_schema)
			PARM_LOCK="--skip-lock-tables"
			;;
		*)
			PARM_LOCK="--lock-tables"
			;;
	esac

	mysqldump ${MYSQL_PARAM} --opt --events --routines --triggers --databases ${i} ${PARM_LOCK} --log-error=${DEST}/${PREFIX_NAME}${i}_${DATE_BACKUP}.err > ${DEST}/${PREFIX_NAME}${i}_${DATE_BACKUP}.sql
	check_compress ${?} ${DEST}/${PREFIX_NAME}${i}_${DATE_BACKUP}.sql
	CR=$(expr $? + ${CR})
done

fin_script ${CR}