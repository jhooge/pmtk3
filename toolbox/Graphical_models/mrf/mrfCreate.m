function mrf = mrfCreate(G, varargin)
%% Create a markov random field
% G is undirected graph, (an adjacency matrix) representing the *node*
% topology. If you specify edge potentials, do not explicitly represent
% them as nodes in this graph.
%
%% Named Inputs
%
% nodePots             - a cell array of either tabularFactors or numeric
%                        matrices representing the node potentials. Use
%                        numeric matrices when parameter tying.
%
% edgePots             - a cell array of either tabularFactors or numeric
%                        matrices representing the edge potentials. If numeric
%                        matrices are passed in, we assume these are all
%                        pairwise. Use numeric matrices when parameter
%                        tying the edges, (which is only supported in the
%                        pairwise case). If you specify numeric matrices,
%                        list them according to the linear indexing of G,
%                        i.e. so that the kth edge is the one
%                        between nodes i and j in this code:
%                        edges = find(tril(G));
%                        [i, j] = ind2sub(size(G), edges(k))
%
%
% localCPDs            - a cell array of local conditional probability
%                        distributions (structs), which 'hang' off of the
%                        nodes to handle (usually continuous) observations.
%                        See condGaussCpd, tabularCpd, noisyOrCpd
%
%
% nodePotPointers      - if specified, nodePots{nodePotPointers(j)} is used
%                        as the potential for node j.
%
% edgePotPointers      - if specified nodePots{edgePotPointers(e)} is used
%                        as the potential for edge e, (see edge ordering
%                        note under edgePots above).
%
% localCPDpointers     - if specified, localCPDs{localCPDpointers(j)} is
%                        used as the localCPD whose parent is node j.
%
% infEngine            - one of {'varelim', 'jtree', 'jtreeLibdai'}
%
% precomputeJtree      - [true] set to false if you don't want to precompute
%                        the jtree.
%%
[nodePots, edgePots, localCPDs, ...
    nodePotPointers, edgePotPointers, localCPDpointers, ...
    precomputeJtree, infEngine] =    ...
    process_options(varargin       , ...
    'nodePots'           , []      , ...
    'edgePots'           , []      , ...
    'localCPDs'          , []      , ...
    'nodePotPointers'    , []      , ...
    'edgePotPointers'    , []      , ...
    'localCPDpointers'   , []      , ...
    'infEngine'          , 'jtree' , ...
    'precomputeJtree'    , true);

nodePots  = cellwrap(nodePots);
edgePots  = cellwrap(edgePots);
localCPDs = cellwrap(localCPDs);
nnodes    = size(G, 1);

%% set default values
if isempty(nodePotPointers)
    if numel(nodePots) == 1
        nodePotPointers = ones(1, nnodes);
    else
        nodePotPointers = 1:nnodes;
    end
end
if isempty(edgePotPointers)
    if numel(edgePots) == 1
        edgePotPointers = ones(1, nedges(G, false));
    else
        edgePotPointers = 1:nedges(G, false);
    end
end
if isempty(localCPDpointers)
    if numel(localCPDs) == 1
        localCPDpointers = ones(1, nnodes);
    else
        localCPDpointers = 1:nnodes;
    end
end
%%
if ~isempty(nodePots);
    nodeFactors = nodePots(nodePotPointers);
    for f=1:numel(nodeFactors)
        if isnumeric(nodeFactors{f})
            family = [neighbors(G, f), f];
            nodeFactors{f} = tabularFactorCreate(nodeFactors{f},  family);
        end
    end
end
if ~isempty(edgePots)
    edges = find(tril(G));
    sz = size(G);
    edgeFactors = edgePots(edgePotPointers);
    for e=1:numel(edgeFactors)
        fac = edgeFactors{e};
        if isnumeric(fac) && ~isempty(fac)
            [i, j] = ind2sub(sz, edges(e));
            f = e + nnodes;
            family = [i j f];
            edgeFactors{e} = tabularFactorCreate(fac, family);
        end
    end
end
edgeFactors = removeEmpty(edgeFactors);

factorGraph = factorGraphCreate(G, nodeFactors, edgeFactors);
mrf = structure(G, nodeFactors, edgeFactors, factorGraph, ...
    localCPDs, localCPDpointers, infEngine, nnodes);
mrf.nedges = nedges(G, false);
mrf.isdirected = false;
mrf.modelType = 'mrf';
%% precompute jtree
if strcmpi(infEngine, 'jtree') && precomputeJtree
    mrf.jtree = jtreeCreate(factorGraph);
end

end