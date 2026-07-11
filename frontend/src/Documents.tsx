import { useEffect, useRef, useState } from 'react'
import { getFamilyStorage } from './familyStorage.ts'
import { type DocumentRecord, TEST_DOCUMENTS } from './testDocuments.ts'

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
  const DOCUMENTS_STORAGE_KEY = 'geetha-documents'
  const [isUploadModalOpen, setIsUploadModalOpen] = useState(false)
  const [documentName, setDocumentName] = useState('')
  const [selectedMemberId, setSelectedMemberId] = useState('')
  const bundledMedicalAssets = [
    {
      label: 'Healthcare sample',
      path: '/medical/healthcare/clinic-visit-sample.png',
    },
    {
      label: 'Report sample',
      path: '/medical/reports/lab-result-sample.png',
    },
  ]
  const [selectedFileName, setSelectedFileName] = useState('')
  const [documents, setDocuments] = useState<DocumentRecord[]>(() => {
    if (typeof window === 'undefined') return [...TEST_DOCUMENTS]
    const raw = window.localStorage.getItem(DOCUMENTS_STORAGE_KEY)
    if (!raw) return [...TEST_DOCUMENTS]
    try {
      const parsed = JSON.parse(raw) as Partial<DocumentRecord>[]
      if (!Array.isArray(parsed)) return [...TEST_DOCUMENTS]
      return parsed
        .filter((doc) => typeof doc?.id === 'string' && typeof doc?.name === 'string')
        .map((doc) => ({
          id: doc.id!,
          name: doc.name!,
          memberId: typeof doc.memberId === 'string' ? doc.memberId : '',
          memberName:
            typeof doc.memberName === 'string' && doc.memberName.trim()
              ? doc.memberName
              : '—',
          uploadedAt: typeof doc.uploadedAt === 'string' ? doc.uploadedAt : undefined,
        }))
    } catch {
      return [...TEST_DOCUMENTS]
    }
  })
  const fileInputRef = useRef<HTMLInputElement | null>(null)

  const storedFamily = getFamilyStorage()
  const members = storedFamily?.members ?? []

  const getMemberName = (memberId: string) => {
    if (!memberId) return '—'
    const m = members.find((x) => x.id === memberId)
    return m ? m.firstName : '—'
  }

  useEffect(() => {
    if (typeof window === 'undefined') return
    window.localStorage.setItem(DOCUMENTS_STORAGE_KEY, JSON.stringify(documents))
  }, [documents])

  const closeUploadModal = () => {
    setIsUploadModalOpen(false)
    setDocumentName('')
    setSelectedMemberId('')
    setSelectedFileName('')
    if (fileInputRef.current) {
      fileInputRef.current.value = ''
    }
  }

  const handleFileSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const selectedFile = event.target.files?.[0]
    if (!selectedFile) return
    setSelectedFileName(selectedFile.name)
    // Default document title to the uploaded file name.
    setDocumentName(selectedFile.name)
  }

  const handleUploadSubmit = (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    if (!selectedFileName.trim()) return
    const name = documentName.trim() || selectedFileName.trim()
    const memberName = getMemberName(selectedMemberId)
    setDocuments((prev) => [
      ...prev,
      {
        id: `doc-${crypto.randomUUID()}`,
        name,
        memberId: selectedMemberId,
        memberName,
        uploadedAt: new Date().toISOString().slice(0, 10),
      },
    ])
    closeUploadModal()
  }

  return (
    <div className="card">
      <h1>Documents</h1>
      {documents.length > 0 ? (
        <ul className="documents-list">
          {documents.map((doc) => (
            <li key={doc.id} className="documents-list-item">
              <span className="documents-list-name">{doc.name}</span>
              <span className="documents-list-member">{doc.memberName || getMemberName(doc.memberId)}</span>
              {doc.uploadedAt ? (
                <span className="documents-list-date">{doc.uploadedAt}</span>
              ) : null}
            </li>
          ))}
        </ul>
      ) : (
        <p className="profile-subtitle">Your documents will appear here.</p>
      )}
      <button
        type="button"
        className="primary"
        onClick={() => setIsUploadModalOpen(true)}
      >
        Upload Document
      </button>

      <div className="card" style={{ marginTop: '1rem' }}>
        <h3>Bundled asset paths</h3>
        <p>Store demo images under the `/medical/...` public path:</p>
        <ul>
          {bundledMedicalAssets.map((asset) => (
            <li key={asset.path}>
              <strong>{asset.label}:</strong> <code>{asset.path}</code>
            </li>
          ))}
        </ul>
      </div>

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
                <input
                  ref={fileInputRef}
                  type="file"
                  className="upload-file-input"
                  onChange={handleFileSelect}
                />
                <button
                  type="button"
                  className="upload-attachment-placeholder"
                  onClick={() => fileInputRef.current?.click()}
                  aria-label="Choose a document from your computer"
                >
                  <AttachmentIcon size={32} />
                  <span>
                    {selectedFileName
                      ? `Selected: ${selectedFileName}`
                      : 'Select file from computer'}
                  </span>
                </button>
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
