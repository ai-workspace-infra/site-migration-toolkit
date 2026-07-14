package cli

import (
	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "platctl",
	Short: "Platform Operations Toolkit CLI",
	Long:  `platctl is the CLI for SVC.plus Platform Operations Toolkit, managing environment lifecycles.`,
}

func Execute() error {
	return rootCmd.Execute()
}
