import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
import matplotlib.ticker as ticker

def plot_h_matrix(csv_file):
    print(f"Reading data from {csv_file}...")
    df = pd.read_csv(csv_file)
    
    fig, ax = plt.subplots(figsize=(12, 7))
    
    # Plot the non-zero elements
    ax.scatter(df['Col'], df['Row'], color='blue', s=1.5, marker='s')
    
    # Invert Y axis for matrix representation
    ax.invert_yaxis()
    
    # Set axis limits strictly to matrix dimensions
    ax.set_xlim(0, 2560)
    ax.set_ylim(1536, 0)
    
    # =========================================================
    # REPLICATING MATLAB'S TICK LOCATOR ALGORITHM
    # =========================================================
    
    # 1. Major Ticks: Exact block boundaries (M = 512)
    ax.xaxis.set_major_locator(ticker.MultipleLocator(512))
    ax.yaxis.set_major_locator(ticker.MultipleLocator(512))
    
    # 2. Minor Ticks: Replicate MATLAB's 'grid minor' behavior
    # Divide the 512 interval into 5 sub-intervals horizontally
    ax.xaxis.set_minor_locator(ticker.AutoMinorLocator(5))
    # Divide the 512 interval into 10 sub-intervals vertically
    ax.yaxis.set_minor_locator(ticker.AutoMinorLocator(10))
    
    # =========================================================
    
    # Enable dashed grid for both major and minor ticks
    ax.grid(which='both', linestyle='--', linewidth=0.7, color='#333333', alpha=0.8)
    
    # Clean up edge ticks to mimic MATLAB's frame style
    ax.tick_params(which='minor', bottom=False, left=False)
    ax.tick_params(which='major', direction='in')

    # Force 1:1 aspect ratio
    ax.set_aspect('equal', adjustable='box')
    
    plt.title('Figure R-1.    Parity Check Matrix H for (n=2048, k=1024) Rate 1/2', fontsize=14, pad=15)
    
    plt.savefig('results/H_matrix.png', dpi=300, bbox_inches='tight')
    print("Plot saved to results/H_matrix.png")
    plt.show()

if __name__ == "__main__":
    plot_h_matrix("data/H_matrix.csv")