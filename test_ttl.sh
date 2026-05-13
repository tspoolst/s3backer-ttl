#!/bin/bash

MNT="/tmp/s3b-mnt"
BKT="/tmp/s3b-bkt"

# Clean up any previous runs
umount $MNT 2>/dev/null
rm -rvf $MNT $BKT
mkdir -vp $MNT $BKT

echo ">>> Mounting s3backer..."
./s3backer --test \
  --blockSize=4k --size=4k \
  --blockCacheSize=10 \
  --blockCacheTimeout=2000 \
  --ttlBonus=2 \
  --ttlMaxLimit=6 \
  --statsFilename=stats \
  --directIO \
  $BKT $MNT

echo ">>> Writing a block..."
dd if=/dev/urandom of=$MNT/file bs=4k count=1 conv=notrunc status=none
sleep 0.5 # let the worker thread sync it to "S3"

echo ">>> Stats after initial write:"
grep -E 'block_cache_current_size|block_cache_read_misses|block_cache_read_hits' $MNT/stats

echo ">>> Waiting 1.5 seconds..."
sleep 1.5

echo ">>> Reading block (this should trigger the TTL bonus)..."
dd if=$MNT/file bs=4k count=1 status=none > /dev/null

echo ">>> Waiting 1 more second..."
sleep 1
# Note: It has been 2.5 seconds since the write. If TTL bonus didn't work, 
# the 2.0s base timeout would have evicted the block by now.

# echo ">>> Stats after second read:"
# grep -E 'block_cache_current_size|block_cache_read_misses|block_cache_read_hits' $MNT/stats

# echo ">>> Reading block again (should be a cache HIT)..."
# dd if=$MNT/file bs=4k count=1 status=none > /dev/null

echo ">>> Stats after second read:"
grep -E 'block_cache_current_size|block_cache_read_misses|block_cache_read_hits' $MNT/stats

gl_wait=4
echo ">>> Waiting ${gl_wait} seconds for TTL to fully expire..."
sleep ${gl_wait}

echo ">>> Reading block final time (should be a cache MISS)..."
dd if=$MNT/file bs=4k count=1 status=none > /dev/null

echo ">>> Stats after expiration:"
grep -E 'block_cache_current_size|block_cache_read_misses|block_cache_read_hits' $MNT/stats

gl_wait=3
echo ">>> Waiting ${gl_wait} seconds for TTL to fully expire..."
sleep ${gl_wait}

echo ">>> Reading block final time (should be a cache MISS)..."
dd if=$MNT/file bs=4k count=1 status=none > /dev/null

echo ">>> Stats after expiration:"
grep -E 'block_cache_current_size|block_cache_read_misses|block_cache_read_hits' $MNT/stats

echo ">>> Unmounting..."
umount $MNT
rm -rf $MNT $BKT
