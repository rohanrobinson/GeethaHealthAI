import { useState } from 'react'
import { useNavigate } from 'react-router-dom'

type FamilyMember = {
  id: string
  firstName: string
  age: string
  role: string
}

function CreateFamily() {
  const navigate = useNavigate()
  const [isMemberModalOpen, setIsMemberModalOpen] = useState(false)
  const [members, setMembers] = useState<FamilyMember[]>([])
  const [memberFirstName, setMemberFirstName] = useState('')
  const [memberAge, setMemberAge] = useState('')
  const [memberRole, setMemberRole] = useState('')
  const [familyName, setFamilyName] = useState('')
  const [isRosterConfirmed, setIsRosterConfirmed] = useState(false)

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    setIsMemberModalOpen(true)
  }

  const handleAddMember = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()

    const trimmedName = memberFirstName.trim()
    if (!trimmedName) {
      return
    }

    setMembers((prevMembers) => [
      ...prevMembers,
      {
        id: crypto.randomUUID(),
        firstName: trimmedName,
        age: memberAge.trim(),
        role: memberRole.trim(),
      },
    ])

    setIsRosterConfirmed(false)
    setMemberFirstName('')
    setMemberAge('')
    setMemberRole('')
    setIsMemberModalOpen(false)
  }

  const handleConfirmRoster = () => {
    if (members.length === 0) {
      return
    }

    setIsRosterConfirmed(true)
    navigate('/family-profile', {
      state: {
        familyName: familyName.trim(),
        members,
      },
    })
  }

  return (
    <div className="card">
      <h1>Add Family Members</h1>
      <form className="modal-body" onSubmit={handleSubmit}>
        <label className="field">
          Family name
          <input
            type="text"
            value={familyName}
            onChange={(event) => setFamilyName(event.target.value)}
            placeholder="Gowda"
          />
        </label>
        <button type="submit" className="primary">
          Add a Family Member 
        </button>
      </form>
      
      {/* Members cards */}
      {members.length > 0 ? (
        <section className="member-roster">
          <h2>{familyName ? `${familyName} ` : ''}Family</h2>
          <div className="member-grid">
            {members.map((member) => (
              <article className="member-card" key={member.id}>
                <h3>{member.firstName}</h3>
                {member.age ? <p>Age: {member.age}</p> : null}
                {member.role ? <p>Role: {member.role}</p> : null}
              </article>
            ))}
          </div>
          <div className="roster-actions">
            <button
              type="button"
              className="primary"
              onClick={handleConfirmRoster}
            >
              Confirm family roster
            </button>
          </div>
          {isRosterConfirmed ? (
            <div className="roster-confirmation" role="status">
              Roster confirmed. You can edit this later.
            </div>
          ) : null}
        </section>
      ) : null}

      {/* Add member modal */}
      {isMemberModalOpen ? (
        <div
          className="modal-backdrop"
          onClick={() => setIsMemberModalOpen(false)}
        >
          <div
            className="modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="add-member-title"
            onClick={(event) => event.stopPropagation()}
          >
            <div className="modal-header">
              <h3 id="add-member-title">Add Family Member</h3>
              <button
                className="modal-close"
                onClick={() => setIsMemberModalOpen(false)}
                aria-label="Close add member modal"
              >
                ✕
              </button>
            </div>
            <form className="modal-body" onSubmit={handleAddMember}>
              <label className="field">
                First name
                <input
                  type="text"
                  value={memberFirstName}
                  onChange={(event) => setMemberFirstName(event.target.value)}
                  placeholder="Rohan"
                />
              </label>
              <label className="field">
                Age
                <input
                  type="text"
                  value={memberAge}
                  onChange={(event) => setMemberAge(event.target.value)}
                  placeholder="34"
                />
              </label>
              <label className="field">
                Role
                <input
                  type="text"
                  value={memberRole}
                  onChange={(event) => setMemberRole(event.target.value)}
                  placeholder="Father"
                />
              </label>
              <button type="submit" className="primary">
                Add member
              </button>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  )
}

export default CreateFamily
