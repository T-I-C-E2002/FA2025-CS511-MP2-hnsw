import faiss
import h5py
import numpy as np
import os
import requests
import time



def evaluate_hnsw():

    # start your code here
    # download data, build index, run query

    # write the indices of the 10 approximate nearest neighbours in output.txt, separated by new line in the same directory
    with h5py.File('/home/bartu_koksal/cs511-mp2/FA2025-CS511-MP2-hnsw/sift-128-euclidean.hdf5', "r") as f:
        print(list(f.keys()))
        xb = f['train'][:] #shape : (1000000, 128)
        #print(xb.shape)
        xq = f['test'][:] #shape : (10000, 128)
        #print(xq.shape)
        gt = f['neighbors'][:] #shape : (10000, 100) indices into train
        #print(gt.shape)
    
    
    #This was for part-0
    M=16
    index = faiss.IndexHNSWFlat(xb.shape[1], M, faiss.METRIC_L2)
    index.hnsw.efConstruction = 200
    index.hnsw.efSearch = 200

    q = xq[:1] #first query from test embeddigns

    if xb.dtype != np.float32:
        xb = xb.astype(np.float32, copy=False)
    if q.dtype != np.float32:
        q = q.astype(np.float32, copy=False)
    
    index.add(xb)
    D, I = index.search(q, 10) #search for 10 nearest neighbours
    top10_indices = I[0].tolist() #indices of 10 nearest neighbours for the first query
    out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "output.txt")
    with open(out_path, "w") as f:
        for idx in top10_indices:
            f.write(f"{idx}\n")
    print(f"Wrote top-10 ANN indices for the first query to {out_path}")
    

    #this is for part-1





if __name__ == "__main__":
    evaluate_hnsw()
