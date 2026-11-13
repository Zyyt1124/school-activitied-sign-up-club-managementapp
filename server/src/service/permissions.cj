package campus.service

import campus.domain.*

/**
 * 权限判断集中在一处，API 层不重复写 if role == ...
 * 返回 Option<BizError>，None 表示通过。
 */
public func canManageClub(actor: Actor, clubId: Int64): Bool {
    match (actor.role) {
        case Admin => true
        case ClubLeader =>
            match (actor.leaderClubId) {
                case Some(leaderClubId) => leaderClubId == clubId
                case None => false
            }
        case Student => false
    }
}

public func requireClubManager(actor: Actor, clubId: Int64): Option<BizError> {
    if (canManageClub(actor, clubId)) {
        return None
    }
    return Some(forbiddenError("FORBIDDEN", "只有本社团负责人或学校管理员可以操作"))
}

public func requireAdmin(actor: Actor): Option<BizError> {
    match (actor.role) {
        case Admin => None
        case Student | ClubLeader => Some(forbiddenError("FORBIDDEN", "只有学校管理员可以操作"))
    }
}
