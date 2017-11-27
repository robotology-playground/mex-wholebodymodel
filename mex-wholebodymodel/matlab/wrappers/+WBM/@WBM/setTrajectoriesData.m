function lnk_trajects = setTrajectoriesData(obj, lnk_trajects, stmPos, start_idx, end_idx)
    if ~isa(lnk_trajects, 'WBM.wbmLinkTrajectory')
        error('WBM::setTrajectoriesData: %s', WBM.wbmErrorMsg.WRONG_DATA_TYPE);
    end
    if ~iscolumn(lnk_trajects)
        error('WBM::setTrajectoriesData: %s', WBM.wbmErrorMsg.WRONG_VEC_DIM);
    end
    ndof = obj.mwbm_model.ndof;
    vlen = ndof + 7;

    [noi, len] = size(stmPos);
    if (len ~= vlen)
        error('WBM::setTrajectoriesData: %s', WBM.wbmErrorMsg.WRONG_MAT_DIM);
    end
    nTraj = size(lnk_trajects,1);

    % get the positions, orientations and the joint positions from the output vector
    % "stmPos" of the integration part of the forward dynamics function:
    switch nargin
        case 5
            WBM.utilities.chkfun.checkCVecDs(start_idx, end_idx, nTraj, nTraj, 'WBM::setTrajectoriesData');
            if ( ~isempty(find(start_idx( (start_idx < 1) | (start_idx > noi) | (start_idx > end_idx) ),1)) || ...
                 ~isempty(find(end_idx( (end_idx < 1) | (end_idx > noi) ),1)) )
                error('WBM::setTrajectoriesData: %s', WBM.wbmErrorMsg.VAL_OUT_OF_BOUNDS);
            end

            % calculate and set the data points of each link trajectory to a
            % specific time section [is, ie] of the given iteration:
            for i = 1:nTraj
                is = start_idx(i,1);
                ie = end_idx(i,1);

                vqT_b = stmPos(is:ie,1:7);
                q_j   = stmPos(is:ie,8:vlen);
                q_j   = q_j.';

                nSteps = ie - is + 1; % = size(vqT_b,1)
                lnk_trajects(i,1) = setTrajectoryDPts(obj, lnk_trajects(i,1), vqT_b, q_j, nSteps);
            end
        case 3
            vqT_b = stmPos(1:noi,1:7);
            q_j   = stmPos(1:noi,8:vlen);
            q_j   = q_j.';

            % calculate and set the data points of each link trajectory
            % for all iteration steps (noi):
            for i = 1:nTraj
                lnk_trajects(i,1) = setTrajectoryDPts(obj, lnk_trajects(i,1), vqT_b, q_j, noi);
            end
        otherwise
            error('WBM::setTrajectoriesData: %s', WBM.wbmErrorMsg.WRONG_NARGIN);
    end
end