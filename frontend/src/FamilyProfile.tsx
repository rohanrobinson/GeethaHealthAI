import { useLocation, useNavigate } from 'react-router-dom'

type FamilyMember = {
  id: string
  firstName: string
  age: string
  role: string
}

type FamilyProfileState = {
  familyName?: string
  members?: FamilyMember[]
}

function FamilyProfile() {
  const navigate = useNavigate()
  const location = useLocation()
  const state = location.state as FamilyProfileState | null
  const members = state?.members ?? []
  const familyLabel = state?.familyName ? `${state.familyName} Family` : 'Family'

  return (
    <div className="card profile-card">
      <div className="profile-header">
        <div>
          <h1>Family profile</h1>
          <p className="profile-subtitle">{familyLabel}</p>
        </div>
        <span className="profile-badge">{members.length} members</span>
      </div>

      {members.length > 0 ? (
        <div className="member-grid">
          {members.map((member) => (
            <article className="member-card" key={member.id}>
              <h3>{member.firstName}</h3>
              {member.age ? <p>Age: {member.age}</p> : null}
              {member.role ? <p>Role: {member.role}</p> : null}
            </article>
          ))}
        </div>
      ) : (
        <p className="profile-subtitle">
          No members have been added yet.
        </p>
      )}

      <div className="profile-actions">
        <button type="button" onClick={() => navigate('/create-family')}>
          Back to roster
        </button>
      </div>
    </div>
  )
}

export default FamilyProfile
