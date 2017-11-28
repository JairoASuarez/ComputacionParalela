#include <stdio.h>
#include <opencv2/opencv.hpp>
#include <pthread.h>

using namespace cv;

char* src;
int kernel, threads, width, height, balance;
Mat image, dst;
	
int blur(int x, int y, int k, int c){
	int ic, ir, fc, fr, halfk = k/2, intensity = 0;
	x-(halfk)+1<0 ? ic = 0 : ic = x-(halfk);
	y-(halfk)+1<0 ? ir = 0 : ir = y-(halfk);
	x+(halfk)+1>height ? fc = height : fc = x+(halfk)+1;
	y+(halfk)+1>width ? fr = width : fr = y+(halfk)+1;

	for(int i=ic; i<fc; i++)
    		for(int j=ir; j<fr; j++)
			intensity += image.at<Vec3b>(i,j)[c];
			//printf ("intensity is %d \n", intensity) ;
	return intensity/(k*k);
}

void *blur_with_threads(void *ap){
	int row = *(int*)ap;
	int maxrow = ((((row/balance) + 1) * balance) -1);
	for(int i=row; i<maxrow; i++){
    		for(int j=0; j<image.cols; j++){
				for(int c=0; c<3; c++){
					dst.at<Vec3b>(i,j)[c] = blur(i,j,kernel,c);
				}
			}
		}
}


int main( int argc, char** argv ){
	
	src = argv[1];
	kernel = atoi(argv[2]);
	threads = atoi(argv[3]);

	if(argc != 4){
		printf("Numero incorrecto de argumentos, deben ser 4\n");
		return -1;
	}

	if(kernel % 2 == 0){
		printf("El numero del kernel debe ser impar");
		return -1;
	}

	if(threads < 1) {
		printf("El numero de hilos no puede ser negativo, debe ser igual o mayor a 1");
		return -1;
	}

	image = imread(src);

	if(!image.data){
		printf("La imagen no se pudo leer\n");
		return -1;
	}

	width = image.cols;
	height = image.rows;
	dst = image.clone();
	pthread_t pids[threads];
	int rv;

	if (threads <= 1){ 
		for(int i=0; i<image.rows; i++){
	    		for(int j=0; j<image.cols; j++){
					for(int c=0; c<3; c++){
						dst.at<Vec3b>(i,j)[c] = blur(i,j,kernel,c);
					}
				}
			}
	} else {
		balance = height/threads;
		for(int k = 0; k < threads; k++){
			rv = pthread_create(&pids[k], NULL, blur_with_threads, new int(k*balance));
			if(rv<0){
            	perror("\n-->Error en thread: ");
            	exit(-1);
        	}	
		}

		for(int l = 0; l < threads; l++){
			pthread_join(pids[l], NULL);
		}
	}

	imwrite("out.jpg", dst);
	return 0;
}
