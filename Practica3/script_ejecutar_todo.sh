echo -e 'RESULTADOS SCRIPT CON KERNEL 21' >> results.txt
for imagen in 720p.jpg 1080p.jpg 4k.jpg
do
echo -e '------------Imagen' $imagen '------------' >> results.txt
for thread in 64 100 300 500 1000 
do 
echo -e '----Hilos' $thread '----'>> results.txt
echo '- Tiempo: ' >> results.txt
sudo time -f "%E" -o results.txt -a ./blur-effect $imagen 21 $thread
echo -e 'segundos\n'>> results.txt
done
done
exit 0
