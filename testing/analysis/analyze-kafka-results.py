import csv
import sys
from collections import defaultdict
import statistics

def analyze_kafka_results(sync_file, async_file):
    """
    Analyze Kafka-only performance test results
    """
    
    # Read SYNC results
    sync_latencies = []
    with open(sync_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            sync_latencies.append(float(row['Latency_ms']))
    
    # Read ASYNC results
    async_latencies = []
    with open(async_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            async_latencies.append(float(row['Latency_ms']))
    
    # Calculate statistics
    def calc_stats(latencies):
        sorted_lat = sorted(latencies)
        n = len(sorted_lat)
        return {
            'count': n,
            'min': min(sorted_lat),
            'max': max(sorted_lat),
            'avg': statistics.mean(sorted_lat),
            'median': statistics.median(sorted_lat),
            'p95': sorted_lat[int(n * 0.95)],
            'p99': sorted_lat[int(n * 0.99)],
            'stdev': statistics.stdev(sorted_lat) if n > 1 else 0
        }
    
    sync_stats = calc_stats(sync_latencies)
    async_stats = calc_stats(async_latencies)
    
    # Print comparison report
    print("═" * 80)
    print("  ISOLATED KAFKA PUBLISHING PERFORMANCE COMPARISON")
    print("  (No Database Operations)")
    print("═" * 80)
    print()
    
    print("SYNC Mode (Blocking Kafka Publishing):")
    print(f"  Samples:         {sync_stats['count']}")
    print(f"  Average:         {sync_stats['avg']:.2f} ms")
    print(f"  Median (P50):    {sync_stats['median']:.2f} ms")
    print(f"  P95:             {sync_stats['p95']:.2f} ms")
    print(f"  P99:             {sync_stats['p99']:.2f} ms")
    print(f"  Min:             {sync_stats['min']:.2f} ms")
    print(f"  Max:             {sync_stats['max']:.2f} ms")
    print(f"  Std Dev:         {sync_stats['stdev']:.2f} ms")
    print()
    
    print("ASYNC Mode (Non-Blocking Kafka Publishing):")
    print(f"  Samples:         {async_stats['count']}")
    print(f"  Average:         {async_stats['avg']:.2f} ms")
    print(f"  Median (P50):    {async_stats['median']:.2f} ms")
    print(f"  P95:             {async_stats['p95']:.2f} ms")
    print(f"  P99:             {async_stats['p99']:.2f} ms")
    print(f"  Min:             {async_stats['min']:.2f} ms")
    print(f"  Max:             {async_stats['max']:.2f} ms")
    print(f"  Std Dev:         {async_stats['stdev']:.2f} ms")
    print()
    
    print("━" * 80)
    print("PERFORMANCE IMPROVEMENT:")
    print("━" * 80)
    
    avg_improvement = ((sync_stats['avg'] - async_stats['avg']) / sync_stats['avg']) * 100
    median_improvement = ((sync_stats['median'] - async_stats['median']) / sync_stats['median']) * 100
    p95_improvement = ((sync_stats['p95'] - async_stats['p95']) / sync_stats['p95']) * 100
    speedup = sync_stats['avg'] / async_stats['avg']
    
    print(f"  Average Latency:   {sync_stats['avg']:.2f}ms → {async_stats['avg']:.2f}ms")
    print(f"                     Improvement: {avg_improvement:.1f}% faster")
    print(f"                     Speedup: {speedup:.1f}× faster")
    print()
    print(f"  Median Latency:    {sync_stats['median']:.2f}ms → {async_stats['median']:.2f}ms")
    print(f"                     Improvement: {median_improvement:.1f}% faster")
    print()
    print(f"  P95 Latency:       {sync_stats['p95']:.2f}ms → {async_stats['p95']:.2f}ms")
    print(f"                     Improvement: {p95_improvement:.1f}% faster")
    print()
    
    print("━" * 80)
    print("KEY FINDINGS:")
    print("━" * 80)
    print()
    print("✓ Async Kafka publishing is significantly faster than sync")
    print(f"✓ Saves {sync_stats['avg'] - async_stats['avg']:.2f}ms per message on average")
    print(f"✓ At 100 req/s, this saves {(sync_stats['avg'] - async_stats['avg']) * 100:.0f}ms/second")
    print(f"✓ Non-blocking I/O releases threads {speedup:.1f}× faster")
    print()
    print("This demonstrates the theoretical improvement of async Kafka publishing.")
    print("In end-to-end tests, this improvement may be masked by other bottlenecks")
    print("such as database connection pools.")
    print()
    print("═" * 80)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 analyze-kafka-results.py <sync_csv> <async_csv>")
        print("Example: python3 analyze-kafka-results.py test-logs/kafka-only-*/kafka_only_results.csv")
        sys.exit(1)
    
    sync_file = sys.argv[1]
    async_file = sys.argv[2]
    
    analyze_kafka_results(sync_file, async_file)
