#!/usr/bin/env python3
"""
High-Load Performance Comparison Analyzer

Analyzes results from high-load-comparison-test.sh and generates
comparison tables and statistics.
"""

import csv
import sys
from pathlib import Path

def analyze_results(csv_file):
    """Analyze and display performance comparison results."""
    
    # Read CSV file
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        data = list(reader)
    
    if not data:
        print("No data found in CSV file")
        return
    
    # Separate SYNC and ASYNC data
    sync_data = [r for r in data if r['Mode'].lower() == 'sync']
    async_data = [r for r in data if r['Mode'].lower() == 'async']
    
    if not sync_data or not async_data:
        print("⚠️  Need both SYNC and ASYNC test results for comparison")
        print(f"   Found: {len(sync_data)} SYNC rounds, {len(async_data)} ASYNC rounds")
        return
    
    # Calculate averages
    def avg(data_list, key):
        values = [float(r[key]) for r in data_list]
        return sum(values) / len(values)
    
    sync_avg_latency = avg(sync_data, 'Avg_Latency_ms')
    async_avg_latency = avg(async_data, 'Avg_Latency_ms')
    
    sync_p95 = avg(sync_data, 'P95_ms')
    async_p95 = avg(async_data, 'P95_ms')
    
    sync_p99 = avg(sync_data, 'P99_ms')
    async_p99 = avg(async_data, 'P99_ms')
    
    sync_throughput = avg(sync_data, 'Throughput_req_per_sec')
    async_throughput = avg(async_data, 'Throughput_req_per_sec')
    
    sync_total = sum(int(r['Total_Requests']) for r in sync_data)
    async_total = sum(int(r['Total_Requests']) for r in async_data)
    
    # Calculate improvements
    latency_improvement = ((sync_avg_latency - async_avg_latency) / sync_avg_latency) * 100
    latency_speedup = sync_avg_latency / async_avg_latency
    
    p95_improvement = ((sync_p95 - async_p95) / sync_p95) * 100
    p99_improvement = ((sync_p99 - async_p99) / sync_p99) * 100
    
    throughput_improvement = ((async_throughput - sync_throughput) / sync_throughput) * 100
    
    # Display results
    print("\n" + "="*80)
    print("HIGH-LOAD PERFORMANCE COMPARISON RESULTS")
    print("="*80)
    print(f"\nTest Configuration:")
    print(f"  • Concurrent Users: {sync_data[0]['Concurrent_Users']}")
    print(f"  • Test Rounds: {len(sync_data)} SYNC, {len(async_data)} ASYNC")
    print(f"  • Duration: {sync_data[0]['Duration_sec']}s per round")
    print(f"  • Metric: POST /api/orders latency (actual order creation)")
    
    print("\n" + "-"*80)
    print(f"{'Metric':<25} {'SYNC (Before)':<20} {'ASYNC (After)':<20} {'Improvement':<15}")
    print("-"*80)
    
    print(f"{'Avg Latency':<25} {sync_avg_latency:>15.2f} ms {async_avg_latency:>15.2f} ms "
          f"{latency_improvement:>10.1f}%")
    print(f"{'P95 Latency':<25} {sync_p95:>15.2f} ms {async_p95:>15.2f} ms "
          f"{p95_improvement:>10.1f}%")
    print(f"{'P99 Latency':<25} {sync_p99:>15.2f} ms {async_p99:>15.2f} ms "
          f"{p99_improvement:>10.1f}%")
    print(f"{'Throughput':<25} {sync_throughput:>14.2f} rps {async_throughput:>14.2f} rps "
          f"{throughput_improvement:>10.1f}%")
    print(f"{'Total Requests':<25} {sync_total:>18,} {async_total:>18,} "
          f"{((async_total-sync_total)/sync_total*100):>10.1f}%")
    
    print("-"*80)
    
    print(f"\n🎯 Key Findings:")
    print(f"   • Response time reduced by {latency_improvement:.1f}% ({sync_avg_latency:.1f}ms → {async_avg_latency:.1f}ms)")
    print(f"   • System is {latency_speedup:.1f}× faster with async Kafka publishing")
    print(f"   • Throughput increased by {throughput_improvement:.1f}% ({sync_throughput:.1f} → {async_throughput:.1f} req/s)")
    print(f"   • P95 latency improved by {p95_improvement:.1f}% (95% of requests)")
    print(f"   • P99 latency improved by {p99_improvement:.1f}% (99% of requests)")
    
    print(f"\n📊 Per-Round Breakdown:")
    print(f"\n{'Mode':<8} {'Round':<8} {'Requests':<12} {'Avg Latency':<15} {'P95':<12} {'P99':<12} {'Throughput':<12}")
    print("-"*80)
    
    for r in sync_data:
        print(f"{'SYNC':<8} {r['Round']:<8} {int(r['Total_Requests']):<12,} "
              f"{float(r['Avg_Latency_ms']):<14.2f}ms {float(r['P95_ms']):<11.0f}ms "
              f"{float(r['P99_ms']):<11.0f}ms {float(r['Throughput_req_per_sec']):<11.2f}rps")
    
    for r in async_data:
        print(f"{'ASYNC':<8} {r['Round']:<8} {int(r['Total_Requests']):<12,} "
              f"{float(r['Avg_Latency_ms']):<14.2f}ms {float(r['P95_ms']):<11.0f}ms "
              f"{float(r['P99_ms']):<11.0f}ms {float(r['Throughput_req_per_sec']):<11.2f}rps")
    
    print("\n" + "="*80)
    
    # Export summary
    summary_file = Path(csv_file).parent / "comparison_summary.txt"
    with open(summary_file, 'w') as f:
        f.write("="*80 + "\n")
        f.write("PERFORMANCE COMPARISON SUMMARY\n")
        f.write("="*80 + "\n\n")
        f.write(f"Latency Improvement: {latency_improvement:.1f}% ({latency_speedup:.1f}× faster)\n")
        f.write(f"Throughput Improvement: {throughput_improvement:.1f}%\n")
        f.write(f"SYNC Avg Latency: {sync_avg_latency:.2f}ms\n")
        f.write(f"ASYNC Avg Latency: {async_avg_latency:.2f}ms\n")
        f.write(f"SYNC Throughput: {sync_throughput:.2f} req/s\n")
        f.write(f"ASYNC Throughput: {async_throughput:.2f} req/s\n")
    
    print(f"\n📝 Summary exported to: {summary_file}")
    print()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 analyze-results.py <csv_file>")
        print("\nExample:")
        print("  python3 analyze-results.py test-logs/high-load-comparison-*/high_load_comparison_results.csv")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    
    if not Path(csv_file).exists():
        print(f"Error: File not found: {csv_file}")
        sys.exit(1)
    
    analyze_results(csv_file)
