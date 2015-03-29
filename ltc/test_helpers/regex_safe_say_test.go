package test_helpers_test

import (
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"

	"github.com/cloudfoundry-incubator/lattice/ltc/test_helpers"
    "github.com/onsi/gomega/gbytes"
)

var _ = Describe("RegexSafeSay", func() {

    var gbytesBuffer *gbytes.Buffer

    BeforeEach(func() {
        gbytesBuffer = gbytes.NewBuffer()
    })

	Describe("Say", func() {
		It("matches weird characters using the say matcher", func() {
            gbytesBuffer.Write([]byte(`match this \|?-^$.(){}`))

			Expect(gbytesBuffer).To(test_helpers.Say(`match this \|?-^$.(){}`))
		})

        It("negated match using the say matcher", func() {
            gbytesBuffer.Write([]byte("say that"))

			Expect(gbytesBuffer).ToNot(test_helpers.Say("different"))
		})
	})

    Describe("SayIncorrectUsage", func() {
        It("matches the incorrect usage message", func() {
            gbytesBuffer.Write([]byte("Incorrect Usage"))

            Expect(gbytesBuffer).To(test_helpers.SayIncorrectUsage())
        })
    })

    Describe("SayNewLine", func() {
        It("matches the new line", func() {
            gbytesBuffer.Write([]byte("\n"))

            Expect(gbytesBuffer).To(test_helpers.SayNewLine())
        })
    })
})
