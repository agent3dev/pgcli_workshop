# Workshop Tests

This folder contains automated tests to verify the workshop functionality.

## test_workshop.sh

Comprehensive test script that validates the entire workshop workflow:

- ✅ Container build and startup
- ✅ Database reset and schema creation
- ✅ Data generation (100k+ records)
- ✅ Schema normalization
- ✅ Index creation
- ✅ Benchmark execution
- ✅ Performance verification

### Running the Tests

```bash
cd tests
./test_workshop.sh
```

### What It Tests

The script simulates a complete workshop run and verifies:

1. **Container Setup**: Builds and starts the workshop container
2. **Database Initialization**: Resets to bad schema with generated data
3. **Normalization**: Loads normalized schema successfully
4. **Indexing**: Creates all required indexes
5. **Performance**: Runs benchmark and checks query times
6. **Cleanup**: Removes test containers and volumes

### Expected Output

```
🧪 Testing Workshop Functionality
==================================
1. Building and starting workshop container...
✅ Container built successfully
✅ Container started successfully
✅ PostgreSQL is ready
2. Testing database reset...
✅ Database reset completed
✅ Bad schema tables created
3. Testing data generation...
✅ Products generated (100000 records)
✅ Orders generated (50000 records)
4. Testing schema normalization...
✅ Normalized schema loaded
✅ Normalized tables created
5. Testing index creation...
✅ Indexes created (10 indexes)
6. Testing benchmark functionality...
✅ Benchmark runs successfully
7. Testing performance improvement...
✅ Query performance is good (12.345 ms)
8. Cleaning up...
✅ Cleanup completed

🎉 All workshop tests passed!
```

### Notes

- Tests use a separate container (`workshop-test`) and volume (`workshop-test-data`) to avoid interfering with development
- The test container uses port 5434 to avoid conflicts
- Tests clean up after themselves
- Performance check expects queries under 50ms with indexes (adjust if needed)</content>
</xai:function_call