// Copyright (c) 2011 Cloudera, Inc. All rights reserved.

namespace cpp impala
namespace java com.cloudera.impala.thrift

include "Types.thrift"
include "Exprs.thrift"
include "Descriptors.thrift"
include "PlanNodes.thrift"

// Parameters for the execution of a plan fragment on a particular node.
struct TPlanExecParams {
  // scan ranges for each of the scan nodes
  1: list<PlanNodes.TScanRange> scanRanges

  // host names of output destinations, one per output partition
  2: list<string> destHosts
}

// Specification of how plan fragment output is partitioned. If it is hash-partitioned,
// partitionBoundaries is empty; instead, the hash value % n is used to create n
// partitions, where n == the number of destination hosts.
struct TOutputPartitionSpec {
  // if true, partition based on hash value of partitionExpr
  1: required bool isHashPartitioned

  // partitionExpr computes partitioning value over output tuples
  2: optional Exprs.TExpr partitionExpr

  // n-1 boundary literal exprs for n partitions
  3: list<Exprs.TExpr> partitionBoundaries
}

// TPlanExecRequest encapsulates info needed to execute a particular
// plan fragment, including how to produce and how to partition its output.
// It leaves out node-specific parameters (see TPlanExecParams).
struct TPlanExecRequest {
  // no plan or descriptor table: query without From clause
  1: optional PlanNodes.TPlan planFragment
  2: optional Descriptors.TDescriptorTable descTbl

  // id of output tuple produced by this plan fragment
  // TODO: do we need this?
  //3: required Types.TTupleId outputTupleId

  // exprs that produce values for slots of output tuple (one expr per slot)
  4: list<Exprs.TExpr> outputExprs

  // Specification of how the output is partitioned, which in conjunction with
  // TPlanExecParams.destHosts determines where each output row is sent.
  // An empty output partition specification in combination with multiple
  // destination nodes means that the output is broadcast to those nodes.
  // If the partition specification is non-empty, TPlanExecParams.destHosts's
  // size must be the same as the number of partitions.
  5: optional TOutputPartitionSpec outputPartitionSpec

  // destination node id
  6: optional Types.TPlanNodeId destNodeId
}

// TQueryExecRequest encapsulates everything needed to execute all plan fragments
// for a single query. It is passed to the backend's coordinator module via a call
// to the native function NativeBackend.ExecQuery() (ie, it is not used as part of any
// Thrift rpc).
// If only a single plan fragment is present, it is executed by the coordinator itself.
struct TQueryExecRequest {
  1: required Types.TUniqueId queryId

  // one request per plan fragment;
  // fragmentRequests[i] may consume the output of fragmentRequests[j > i];
  // fragmentRequests[0] contains the coordinator fragment
  2: list<TPlanExecRequest> fragmentRequests

  // hosts on which to execute plan fragments;
  // execNodes.size() == fragmentRequests.size() - 1, and fragmentRequests[i+1] is
  // executed on execNodes[i] (fragmentRequests[0] is the coordinator fragment, which
  // is executed by the coordinator itself)
  3: list<list<string>> execNodes

  // node-specific request parameters;
  // nodeRequestParams[i][j] is the parameter for fragmentRequests[i] executed on 
  // execNodes[i-1][j]
  4: list<list<TPlanExecParams>> nodeRequestParams

  // if true, return result in ascii, otherwise return in binary format
  // (see TColumnValue)
  5: required bool asAscii

  // if true, abort execution on the first error
  6: required bool abortOnError

  // maximum # of errors to be reported
  7: required i32 maxErrors

  // for debugging: set batch size used by backend internally;
  // a size of 0 indicates backend default
  8: required i32 batchSize

  // for debugging purposes (to allow backend to log the query string)
  9: optional string selectStmt;
}

// Execution status
struct TExecStatus {
  1: optional string errorMsg
}

service ImpalaBackendService {
  // Synchronous execution of plan fragment. Returns completion status.
  TExecStatus ExecPlanFragment(
      1:Types.TUniqueId queryId, 2:TPlanExecRequest request, 3:TPlanExecParams params);
}
