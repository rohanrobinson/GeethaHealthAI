import { useEffect, useMemo, useState } from 'react'
import { useLocation, useNavigate, useParams } from 'react-router-dom'
import { Accordion } from '@mantine/core'
import { getFamilyStorage, updateMemberStorage } from './familyStorage.ts'

type FamilyMember = {
  id: string
  firstName: string
  age: string
  role: string
}

type MemberProfileState = {
  familyName?: string
  members?: FamilyMember[]
}

function MemberProfile() {
  const navigate = useNavigate()
  const { memberId } = useParams()
  const location = useLocation()
  const state = location.state as MemberProfileState | null
  const storedFamily = getFamilyStorage()
  const members = state?.members?.length ? state.members : storedFamily?.members ?? []

  const member = useMemo(
    () => members.find((item) => item.id === memberId),
    [members, memberId]
  )

  const [firstName, setFirstName] = useState(member?.firstName ?? '')
  const [age, setAge] = useState(member?.age ?? '')
  const [role, setRole] = useState(member?.role ?? '')

  const familyName = state?.familyName ?? storedFamily?.familyName ?? ''
  const familyLabel = familyName ? `${familyName} Family` : 'Family'

  useEffect(() => {
    setFirstName(member?.firstName ?? '')
    setAge(member?.age ?? '')
    setRole(member?.role ?? '')
  }, [member])

  const handleSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!memberId) {
      return
    }

    const updated = updateMemberStorage(memberId, {
      firstName: firstName.trim(),
      age: age.trim(),
      role: role.trim(),
    })

    if (updated) {
      navigate('/family-profile', {
        state: {
          familyName: updated.familyName,
          members: updated.members,
        },
      })
    }
  }

  if (!member) {
    return (
      <div className="card profile-card">
        <h1>Member profile</h1>
        <p className="profile-subtitle">
          We could not find that family member.
        </p>
        <div className="profile-actions">
          <button
            type="button"
            onClick={() =>
              navigate('/family-profile', {
                state: {
                  familyName,
                  members,
                },
              })
            }
          >
            Back to family
          </button>
        </div>
      </div>
    )
  }

  return (
    <div className="card profile-card">
      <div className="profile-header">
        <div>
          <h1>{member.firstName}&apos;s profile</h1>
          <p className="profile-subtitle">{familyLabel}</p>
        </div>
      </div>

      <form className="modal-body profile-form" onSubmit={handleSubmit}>
        <Accordion defaultValue="basics" variant="contained" radius="md">
          <Accordion.Item value="basics">
            <Accordion.Control>Basics</Accordion.Control>
            <Accordion.Panel>
              <label className="field">
                First name
                <input
                  type="text"
                  value={firstName}
                  onChange={(event) => setFirstName(event.target.value)}
                />
              </label>
              <label className="field">
                Age
                <input
                  type="text"
                  value={age}
                  onChange={(event) => setAge(event.target.value)}
                />
              </label>
              <label className="field">
                Role
                <input
                  type="text"
                  value={role}
                  onChange={(event) => setRole(event.target.value)}
                />
              </label>
            </Accordion.Panel>
          </Accordion.Item>

          <Accordion.Item value="conditions">
            <Accordion.Control>Conditions</Accordion.Control>
            <Accordion.Panel>
              <p className="profile-subtitle">No conditions added yet.</p>
            </Accordion.Panel>
          </Accordion.Item>

          <Accordion.Item value="medications">
            <Accordion.Control>Medications</Accordion.Control>
            <Accordion.Panel>
              <p className="profile-subtitle">No medications added yet.</p>
            </Accordion.Panel>
          </Accordion.Item>

          <Accordion.Item value="appointments">
            <Accordion.Control>Appointments</Accordion.Control>
            <Accordion.Panel>
              <p className="profile-subtitle">No appointments scheduled yet.</p>
            </Accordion.Panel>
          </Accordion.Item>
        </Accordion>

        <div className="profile-actions">
          <button type="button" onClick={() => navigate('/family-profile')}>
            Back to family
          </button>
          <button type="submit" className="primary">
            Save changes
          </button>
        </div>
      </form>
    </div>
  )
}

export default MemberProfile
