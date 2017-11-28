#include <stdio.h>
#include <iostream>
#include <opencv2/opencv.hpp>
#include <cuda.h>
#include <cuda_runtime.h>

using namespace std;
using namespace cv;

__device__ int blur_pixel(const int* image, int x, int y, int width, int height, int k){

	int ic, ir, fc, fr, n;
	x-(k/2)+1<0 ? ic = 0 : ic = x-(k/2);
	y-(k/2)+1<0 ? ir = 0 : ir = y-(k/2);
	x+(k/2)+1>width ? fc = width : fc = x+(k/2)+1;
	y+(k/2)+1>height ? fr = height : fr = y+(k/2)+1;

	int red = 0, green = 0, blue = 0;
	for(int i=ic; i<fc; i++){
    		for(int j=ir; j<fr; j++){
			n = image[j+i*height];
			blue += (n % 1000);
			green += (n/1000) % 1000;
			red += (n/1000000) % 1000;
		}
	}

	blue = blue / (k*k);
	green = green / (k*k);
	red = red / (k*k);
	return (red*1000000)+(green*1000)+blue;
}

//Funcion de cada hilo.
__global__ void blur_thread(const int* d_in, const int width, const int height, const int kernel, const int total_threads, int* d_out){
	
	int id = blockDim.x * blockIdx.x + threadIdx.x;
	int ir = id * ( height / total_threads );
	int fr = (id + 1) * ( height / total_threads );

	if(id < height){
		for(int i=0; i<width; i++){
			for(int j=ir; j<fr; j++){
				d_out[j+i*height] = blur_pixel(d_in, i, j, width, height, kernel);
			}
		}
	}
}


//Main.
int main(int argc, char** argv){

	char* src;
	Mat img, dst;
	int kernel, threads, width, height;
		
	src = argv[1];
	kernel = atoi(argv[2]);
	threads = atoi(argv[3]);
	
	if(argc != 4){
		cout<<"Numero incorrecto de argumentos.\n";
		return -1;
	}

	img = imread(src);
	if(!img.data){
		cout<<"Imagen no reconocida.\n";
		return -1;
	}

	width = img.cols;
	height = img.rows;
	dst = img.clone();
	cudaError_t err = cudaSuccess;

	size_t size = width * height * sizeof(int);
	int *h_in = (int *)malloc(size);
	int *h_out = (int *)malloc(size); 

	int count = 0;
	for(int i=0; i<width; i++){
		for(int j=0; j<height; j++){
			h_in[count] = img.at<Vec3b>(j,i)[0];
			h_in[count] += img.at<Vec3b>(j,i)[1] * 1000;
			h_in[count] += img.at<Vec3b>(j,i)[2] * 1000000;
			count++;
		}
	}

	int *d_in = NULL;
	err = cudaMalloc((void **)&d_in, size);
	if(err != cudaSuccess){
		cout<<"Error separando espacio imagen normal en GPU "<<cudaGetErrorString(err)<<endl;
		return -1;
	}

	int *d_out = NULL;
	err = cudaMalloc((void **)&d_out, size);
	if(err != cudaSuccess){
		cout<<"Error separando espacio imagen difuminada en GPU "<<cudaGetErrorString(err)<<endl;
		return -1;
	}

	err = cudaMemcpy(d_in, h_in, size, cudaMemcpyHostToDevice);
	if (err != cudaSuccess){
		cout<<"Error copiando datos a GPU "<<cudaGetErrorString(err)<<endl;
		return -1;
	}

	int blocksPerGrid = (height + threads - 1) / threads;	
	blur_thread<<<blocksPerGrid, threads>>>(d_in, width, height, kernel, height, d_out);
	err = cudaGetLastError();
	if (err != cudaSuccess){
		cout<<"Fallo al lanzar Kerndel de GPU "<<cudaGetErrorString(err)<<endl;
		return -1;
	}
	
    	err = cudaMemcpy(h_out, d_out, size, cudaMemcpyDeviceToHost);
	if (err != cudaSuccess){
		cout<<"Error copiando desde GPU a CPU "<<cudaGetErrorString(err)<<endl;
		return -1;
	}

	count = 0;
	for(int i=0; i<width; i++){
		for(int j=0; j<height; j++){
			dst.at<Vec3b>(j,i)[0] = (unsigned char)((h_out[count]) % 1000);
			dst.at<Vec3b>(j,i)[1] = (unsigned char)((h_out[count]/1000) % 1000);
			dst.at<Vec3b>(j,i)[2] = (unsigned char)((h_out[count]/1000000) % 1000);
			count++;
		}
	}
	imwrite("out.jpg", dst);
	
	err = cudaFree(d_in);
	if (err != cudaSuccess){
	        cout<<"Error liberando memoria de imagen normal "<<cudaGetErrorString(err)<<endl;
		return -1;
    	}

	err = cudaFree(d_out);
	if (err != cudaSuccess){
	        cout<<"Error liberando memoria de imagen difuminada "<<cudaGetErrorString(err)<<endl;
		return -1;
    	}

	free(h_in);
	free(h_out);

	return 0;
}
