import { useLocation, useNavigate } from 'react-router-dom'
import { getFamilyStorage } from './familyStorage.ts'

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
  const storedFamily = getFamilyStorage()
  const members = state?.members?.length ? state.members : storedFamily?.members ?? []
  const familyName = state?.familyName ?? storedFamily?.familyName ?? ''
  const familyLabel = familyName ? `${familyName} Family` : 'Family'

  return (
    <div className="card profile-card">
      <div className="profile-header">
        <div>
          <h1>{familyLabel}</h1>
        </div>
        <span className="profile-badge">{members.length} members</span>
      </div>

      {members.length > 0 ? (
        <div className="member-grid">
          {members.map((member) => (
            <article
              className="member-card member-card--clickable"
              key={member.id}
              onClick={() =>
                navigate(`/member-profile/${member.id}`, {
                  state: {
                    familyName,
                    members,
                  },
                })
              }
              onKeyDown={(event) => {
                if (event.key === 'Enter' || event.key === ' ') {
                  event.preventDefault()
                  navigate(`/member-profile/${member.id}`, {
                    state: {
                      familyName,
                      members,
                    },
                  })
                }
              }}
              role="button"
              tabIndex={0}
            >
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
