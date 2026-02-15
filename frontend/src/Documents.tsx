import { useState } from 'react'
import { getFamilyStorage } from './familyStorage.ts'

function AttachmentIcon({ size = 24, title = 'Attachment' }: { size?: number; title?: string }) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      role="img"
      aria-label={title}
    >
      <title>{title}</title>
      <path d="m21.44 11.05-9.44 9.44a6 6 0 0 1-8.49-8.49l9.44-9.44a4 4 0 0 1 5.66 5.66l-9.44 9.44a2 2 0 0 1-2.83-2.83l8.49-8.48" />
    </svg>
  )
}

function Documents() {
  const [isUploadModalOpen, setIsUploadModalOpen] = useState(false)
  const [documentName, setDocumentName] = useState('')
  const [selectedMemberId, setSelectedMemberId] = useState('')

  const storedFamily = getFamilyStorage()
  const members = storedFamily?.members ?? []

  const closeUploadModal = () => {
    setIsUploadModalOpen(false)
    setDocumentName('')
    setSelectedMemberId('')
  }

  const handleUploadSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    closeUploadModal()
  }

  return (
    <div className="card">
      <h1>Documents</h1>
      <p>Your documents will appear here.</p>
      <button
        type="button"
        className="primary"
        onClick={() => setIsUploadModalOpen(true)}
      >
        Upload Document
      </button>

      {isUploadModalOpen ? (
        <div
          className="modal-backdrop"
          onClick={closeUploadModal}
        >
          <div
            className="modal"
            role="dialog"
            aria-modal="true"
            aria-labelledby="upload-document-title"
            onClick={(e) => e.stopPropagation()}
          >
            <div className="modal-header">
              <h3 id="upload-document-title">Upload Document</h3>
              <button
                type="button"
                className="modal-close"
                onClick={closeUploadModal}
                aria-label="Close upload document modal"
              >
                ✕
              </button>
            </div>
            <form className="modal-body" onSubmit={handleUploadSubmit}>
              <label className="field">
                Document name
                <input
                  type="text"
                  value={documentName}
                  onChange={(e) => setDocumentName(e.target.value)}
                  placeholder="e.g. Lab results"
                />
              </label>
              <label className="field">
                Family member
                <select
                  value={selectedMemberId}
                  onChange={(e) => setSelectedMemberId(e.target.value)}
                >
                  <option value="">Select a family member</option>
                  {members.map((m) => (
                    <option key={m.id} value={m.id}>
                      {m.firstName}
                    </option>
                  ))}
                </select>
              </label>
              <div className="field">
                <span className="upload-attachment-placeholder" aria-hidden>
                  <AttachmentIcon size={32} />
                  <span>Attachment (coming soon)</span>
                </span>
              </div>
              <div className="modal-actions">
                <button type="button" onClick={closeUploadModal}>
                  Cancel
                </button>
                <button type="submit" className="primary">
                  Upload
                </button>
              </div>
            </form>
          </div>
        </div>
      ) : null}
    </div>
  )
}

export default Documents
